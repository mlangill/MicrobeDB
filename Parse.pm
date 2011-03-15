package MicrobeDB::Parse;

#Parse.pm parses NCBI and custom flat files into MicrobeDB objects (when are then loaded into the database)
#perldoc Parse - for more information (or see end of this file)

use strict;
use warnings;

#inherit common methods and fields from the MicrobeDB class
use base ("MicrobeDB::MicrobeDB");

use Carp;
use XML::Simple;
use Log::Log4perl qw(get_logger :nowarn);

use MicrobeDB::GenomeProject;
use MicrobeDB::Replicon;
use MicrobeDB::Gene;
use MicrobeDB::Search;

use Bio::SeqIO;
use LWP::Simple;
use File::Basename;

my $logger = Log::Log4perl->get_logger();

my %valid_gene_types=qw(CDS 1 tRNA 1 rRNA 1 ncRNA 1 misc_RNA 1 tmRNA 1);

use fields qw(gpo);

sub new {

	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

	#Set each attribute that is given as an arguement
	foreach my $attr ( keys(%arg) ) {

		#set the attribute in the object
		$self->$attr( $arg{$attr} );
	}

	unless($self->{gpo}){
	    $self->gpo(new MicrobeDB::GenomeProject());
	}
	return $self;
}

sub parse_genome{
    my ($self,$dir)=@_;

    my $gpo=$self->gpo();
    $gpo->gpv_directory($dir);

    my @files = glob($dir.'*');

    #get genbank files
    my @gbk_files = grep{/.gbk/i || /.genbank/i ||/.embl/i}@files;

    unless(@gbk_files){
	$logger->error("No genbank files found in directory: $dir");
	die ("No genbank files found in directory: $dir")
    }
    foreach my $file_name (@gbk_files){
	$self->parse_gbk($file_name);
    }
    
    if($gpo->taxon_id){
	$self->parse_taxonomy();
    }
    unless($gpo->org_name){
	$logger->warn("org_name not set, so using directory name for org_name in genomeproject");
	$gpo->org_name(basename($dir));
    }
    	
    (my  $parentdir = $dir ) =~ s/(.+)\/.+\/?/$1/;
    my $NCBI_comp_genomes = "$parentdir/NCBI_completegenomes.txt";
    my $NCBI_org_info = "$parentdir/NCBI_orginfo.txt";
    if(-e $NCBI_org_info){
	$logger->debug("Parsing file: $NCBI_org_info");
	$self->parse_ncbiorginfofile( $NCBI_org_info);
    }else{
	$logger->warn("Can't find file:$NCBI_comp_genomes . GenomeProject table will not contain much organism information.");
    }
    if(-e $NCBI_comp_genomes){
	$logger->debug("Parsing file: $NCBI_comp_genomes");
	$self->parse_ncbicompgenomefile( $NCBI_comp_genomes);
    }else{
	$logger->warn("Can't find file:$NCBI_comp_genomes . GenomeProject table will be missing a few fields of information.");
    }

    return $gpo;

}

sub parse_taxonomy{
    my ($self)=@_;
    my $gpo = $self->gpo();
    my $taxon_id = $gpo->taxon_id;
    my $so = new MicrobeDB::Search;
    my ($taxon)    = $so->table_search( 'taxonomy', { taxon_id => $taxon_id } );
    #set the 
    if (! (defined($taxon) && $taxon->{'superkindom'}) ) {
	eval {
	    my ( $lineage, %lineage_full ) = get_taxonomy( $taxon_id );
	    
	    #Set the lineage information into our massive hash
	    $gpo->lineage($lineage);
	    
	    #put the taxonomy annotations into the genome project object
	    foreach ( keys(%lineage_full) ) {
		$gpo->$_( $lineage_full{$_} );
	    }
	};
	if ($@) {
	    $logger->error("Couldn't retrieve taxon information from NCBI for taxon id:$taxon_id.");
	}
    }
}



sub parse_gbk {
	my ($self,$file) = @_;

	my $genome=$self->gpo();
	my ($IN,$file_name) = $self->load_file($file);
	my $file_types  = $self->get_file_type_list((fileparse($file))[1],$file_name);
	
	while ( my $seq = <$IN> ) {

	    #set stuff about the replicon
	    my $rep= new MicrobeDB::Replicon();
	    my $def = $seq->desc();
	    $rep->definition($def);
	    $rep->rep_size($seq->length());
	    $rep->rep_seq($seq->seq());
	    $rep->file_name($file_name);
	    $rep->file_types($file_types);
	    $rep->rep_accnum($seq->accession_number());

	    my $rep_ginum = $seq->primary_id();
	    unless($rep_ginum =~ /\D/){
		$rep->rep_ginum($rep_ginum);
	    }

	    my $rep_type;
	    if ( $def =~ /plasmid/i ) {
		$rep_type = 'plasmid';
	    } elsif($def =~/chromosome/i || $def =~ /complete genome/i) {
		$rep_type = 'chromosome';
	    }else{
		$rep_type='contig';
	    }
	    $rep->rep_type($rep_type);

	    my $cds_count=0;
	    my $gene_count=0;
	    my $rna_count=0;
	    
	    foreach my $feat ($seq->get_SeqFeatures()) {
		my $gene_type = $feat->primary_tag();
		if($gene_type eq 'source' && ! defined($genome->taxon_id())){
		    my ($org_name)= $feat->has_tag('organism') ? $feat->get_tag_values('organism') : '';
		    $genome->org_name($org_name) if $org_name;
		    my @db_xref = $feat->has_tag('db_xref') ? $feat->get_tag_values('db_xref') : '';
		    my $taxon_id;
		    foreach (@db_xref) {
			if (/taxon:(\d+)/) {
			    $genome->taxon_id($1);
			    last;
			}
		    }
		}
		next unless $valid_gene_types{$gene_type};
		$gene_count++;
		my $protein_seq = '';
		if ( $gene_type eq 'CDS' ) {
		    $cds_count++;
		    if ( $feat->has_tag('translation') ) {
			($protein_seq) = $feat->get_tag_values('translation');
		    } else {
			if ($feat->has_tag('pseudo')){
			    #skip pseudogenes
			    next;
			}else{
			    $logger->warn("No translation available for CDS.!\n");
			}
			
		    }
		}else{
		    #assume it is a rna gene
		    $rna_count++;
		}
		my $start    = $feat->start();
		my $end      = $feat->end();
		my $gene_length   = $feat->length();# $gene_end - $gene_start ) + 1;
		my $strand   = $feat->strand();
		my $gene_seq = $feat->seq->seq();
		
		my ($product)   = $feat->has_tag('product') ? $feat->get_tag_values('product') : '';
		my ($gene_name) = $feat->has_tag('gene')    ? $feat->get_tag_values('gene')    : '';
		my ($locus_tag) =
		    $feat->has_tag('locus_tag')
		    ? $feat->get_tag_values('locus_tag')
		    : '';
		my ($protein_accnum) =
		    $feat->has_tag('protein_id')
		    ? $feat->get_tag_values('protein_id')
		    : '';
		
		my @db_xref = $feat->has_tag('db_xref') ? $feat->get_tag_values('db_xref') : '';
		
		my ( $pid, $gid );
		foreach (@db_xref) {
		    if (/GI:(\d+)/) {
			$pid = $1;
		    } elsif (/GeneID:(\d+)/) {
			$gid = $1;
		    }
		}
		
		my $gene= new MicrobeDB::Gene (
		    'gene_type'      => $gene_type,
		    'gene_start'          => $start,
		    'gene_end'            => $end,
		    'gene_length'		=> $gene_length,
		    'gene_strand'         => $strand,
		    'gene_product'        => $product,
		    'gene_seq'       => $gene_seq,
		    'protein_seq'    => $protein_seq,
		    'gene_name'      => $gene_name,
		    'locus_tag'      => $locus_tag,
		    'protein_accnum' => $protein_accnum,
		    'gid'            => $gid,
		    'pid'            => $pid,
		    );
		$rep->add_gene($gene);
	    }
	    #finish off the replicon information
	    $rep->cds_num($cds_count);
	    $rep->protein_num($cds_count);
	    $rep->gene_num($gene_count);
	    $rep->rna_num($rna_count);
	    
	    $genome->add_replicon($rep);
	}
	return $genome;
}
sub parse_ncbicompgenomefile {
    my($self,$complete_genome_file)=@_;
    my $gpo=$self->gpo();
    my $gp_id=$gpo->gp_id();
    
    unless($gp_id){
	$logger->warn("No gp_id so can't look up organism information in $complete_genome_file");
	return;
    }
    open( my $COMPFILE, $complete_genome_file ) or die "Can't read file: $complete_genome_file\n";
    my @headings;
    my $found_orginfo=0;
    my %comp_org_parse;
    while (<$COMPFILE>) {
	chomp;
	if (/^## Columns:\s+(.+)$/) {
	    @headings = split( /\t/, $1 );
	    for ( my $cnum = 0 ; $cnum < scalar(@headings) ; $cnum++ ) {
		$headings[$cnum] =~ s/^"(.+)"$/$1/;
	    }
	} elsif (/^\d+\s+\w+/) {
	    my @entries = split(/\t/);
	    
	    if ( $entries[1] == $gp_id ) {
		my $i = 0;
		foreach (@entries) {
		    $comp_org_parse{ $headings[$i] } = $_;
		    $i++;
		}
		$found_orginfo=1;
		last;
	    }   
	}
    }
    
    if($found_orginfo){
	#map the old code parse hash to the gpo
	$gpo->centre($comp_org_parse{'List of Center/Consortium (pipe separated)'}) if exists($comp_org_parse{'List of Center/Consortium (pipe separated)'});

	if(exists($comp_org_parse{'Released date'})){
	    my ( $month, $day, $year ) = split /\//, $comp_org_parse{'Released date'};
	    $day   =~ s/(\d)/0$1/ if ( $day   =~ /^\d$/ );
	    $month =~ s/(\d)/0$1/ if ( $month =~ /^\d$/ );
	    $gpo->release_date("$year-$month-$day");
	}

	#note these will be calculated from the replicons if not set here during the loading of the gpo
	$gpo->chromosome_num($comp_org_parse{'Number of Chromosomes'}) if exists($comp_org_parse{'Number of Chromosomes'});
	$gpo->plasmid_num($comp_org_parse{'Number of Plasmids'}) if exists($comp_org_parse{'Number of Plasmids'});

    }else{
	$logger->warn("Couldn't find Project ID: $gp_id within the complete_genome_file: $complete_genome_file . A few fields in GenomeProject will not be filled for this organism");	
    }
}

sub parse_ncbiorginfofile {
    my($self,$org_info_file)=@_;
    my $gpo=$self->gpo();
    my $taxon_id=$gpo->taxon_id();

    unless($taxon_id){
	$logger->warn("No taxon_id so can't look up organism information in $org_info_file");
	return;
    }

    my @headings;
    my $found_orginfo=0;
    my %info_org_parse;
    open( my $INFOFILE, $org_info_file ) or die "Can't open file: $org_info_file\n";
    #use some old parsing code here
    while (<$INFOFILE>) {
	chomp;
	if (/^\#\# Columns:\s+(.+)$/) {
	    @headings = split( /\t/, $1 );
	    for ( my $cnum = 0 ; $cnum < scalar(@headings) ; $cnum++ ) {
		$headings[$cnum] =~ s/^"(.+)"$/$1/;
	    }
	} elsif (/^\d+\s+\w+/) {
	    my @entries = split(/\t/);
	    if ( $entries[2] == $taxon_id ) {
		my $i=0;
		foreach (@entries) {
		    $info_org_parse{ $headings[$i] } = $_;
		    $i++;
		}
		$found_orginfo=1;
		last;
	    }
	}
    }
    if($found_orginfo){
	#map the old code parse hash to the gpo
	$gpo->gp_id($info_org_parse{'Project ID'}) if exists($info_org_parse{'Project ID'});
	$gpo->gram_stain($info_org_parse{'Gram Stain'}) if exists($info_org_parse{'Gram Stain'});
	$gpo->disease($info_org_parse{'Disease'}) if exists($info_org_parse{'Disease'});
	$gpo->pathogenic_in($info_org_parse{'Pathogenic in'}) if exists($info_org_parse{'Pathogenic in'});
	$gpo->temp_range($info_org_parse{'Temp. range'}) if exists($info_org_parse{'Temp. range'});
	$gpo->habitat($info_org_parse{'Habitat'}) if exists($info_org_parse{'Habitat'});
	$gpo->shape($info_org_parse{'Shape'}) if exists($info_org_parse{'Shape'});
	$gpo->arrangement($info_org_parse{'Arrangment'}) if exists($info_org_parse{'Arrangment'});
	$gpo->endospore($info_org_parse{'Endospores'}) if exists($info_org_parse{'Endospores'});
	$gpo->motility($info_org_parse{'Motility'}) if exists($info_org_parse{'Motility'});
	$gpo->salinity($info_org_parse{'Salinity'}) if exists($info_org_parse{'Salinity'});
	$gpo->oxygen_req($info_org_parse{'Oxygen Req'}) if exists($info_org_parse{'Oxygen Req'});
	
	#note these will be calculated from the replicons if not set here during the loading of the gpo
	$gpo->genome_size($info_org_parse{'Genome Size'}) if exists($info_org_parse{'Genome Size'});

	my $gc_content = $info_org_parse{'GC Content'} if exists($info_org_parse{'GC Content'});
	if($gc_content =~ /\d+/){
	    $gpo->genome_gc($gc_content);
	}
	
	my $pathogenic_in=$gpo->pathogenic_in();
	if($pathogenic_in){
	    my $patho_status;
	    if ( $pathogenic_in eq 'No' ) {
		$patho_status = 'nonpathogen';
	    } elsif ( $pathogenic_in =~ /^\s*$/ ) {
		$patho_status = 'unknown';
	    } else {
		$patho_status = 'pathogen';
	    }
	    $gpo->patho_status($patho_status);
	}
	
    }else{
	$logger->warn("Couldn't find taxon id: $taxon_id within the org_info_file: $org_info_file . Many fields in GenomeProject will not be filled for this organism");
    }

}


#load a file(s) into bioperl
#accept gzip files
#guess file type by extension
sub load_file{
    my ($self, $file)=@_;
   	$logger->info("Parsing file: $file");
	my($name,$path,$file_suffix)=fileparse($file,qr/\.[^.]*/);

    my $format_suffix;
    my $FH_IN;
    if($file_suffix eq '.gzip' || $file_suffix eq '.gz'){
	    $logger->debug("File is gzipped.");
	    open($FH_IN,"zcat $file|");
	    ($name,$path,$format_suffix)=fileparse($name,qr/\.[^.]*/);
	    $file_suffix=$format_suffix .$file_suffix;
	}else{
	    $format_suffix=$file_suffix;
	    $logger->debug("File is not gzipped.");
	    open($FH_IN,$file);
	}
	my $format;
	if($format_suffix =~ /genbank/i || $format_suffix =~ /gbk/i){
	    $format='genbank';
	}elsif($format_suffix =~ /fasta/i|| $format_suffix =~ /fa/i || $format_suffix =~ /fna/i || $format_suffix =~ /faa/i || $format_suffix =~ /ffn/i){
	    $format='fasta';
	}elsif($format_suffix =~ /embl/i){
	    $format='embl';
	}else{
	    $logger->fatal("Don't know how to handle file with suffix: $format_suffix !");
	}
	$logger->debug("Giving BioPerl file format: $format");
	my $IN = Bio::SeqIO->newFh(
	    -fh   => $FH_IN,
	    -format => $format
	    );
    
    return $IN,$name,$file_suffix;
	
}


#Retrieves taxon information from NCBI's website using Eutils
#Input: a NCBI taxon id
#Output: the lineage, and the full taxon
sub get_taxonomy {
	my ($taxon_id) = @_;
	my $eutil      = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?';
	my $email      = 'morgan.g.i.langille@gmail.com';
	my $tool_name  = "microbedb";

	my $efetch = "$eutil" . "db=taxonomy&id=$taxon_id&report=xml&mode=text&email=$email&tool=$tool_name";

	#get the results in XML from NCBI
	my $xml_results = get($efetch);

	#Convert the XML into a hash
	my $xml          = new XML::Simple();
	my $nice_results = $xml->XMLin($xml_results);

	my @full_lineage = @{ $nice_results->{Taxon}{LineageEx}{Taxon} };

	#the first one is not useful
	#shift(@full_lineage);

	my %lineage_hash;
	foreach (@full_lineage) {
		my $rank = $_->{Rank};
		my $name = $_->{ScientificName};

		#check the rank and if we want it set it in the object
		if ( good_rank($rank) ) {
			$lineage_hash{$rank} = $name;
		}
	}

	#Look for synonyms
	if ( defined( $nice_results->{Taxon}{OtherNames}{EquivalentName} ) ) {
		my $synonyms;
		if ( ref( $nice_results->{Taxon}{OtherNames}{EquivalentName} ) eq 'ARRAY' ) {
			$synonyms = join( "; ", @{ $nice_results->{Taxon}{OtherNames}{EquivalentName} } );
		} else {
			$synonyms = $nice_results->{Taxon}{OtherNames}{EquivalentName};
		}
		$lineage_hash{'synonyms'} = $synonyms;
	}
	if ( defined( $nice_results->{Taxon}{OtherNames}{Synonym} ) ) {
		my $synonyms;
		if ( ref( $nice_results->{Taxon}{OtherNames}{Synonym} ) eq 'ARRAY' ) {
			$synonyms = join( "; ", @{ $nice_results->{Taxon}{OtherNames}{Synonym} } );
		} else {
			$synonyms = $nice_results->{Taxon}{OtherNames}{Synonym};
		}
		if ( defined( $lineage_hash{'synonyms'} ) ) {
			$lineage_hash{'synonyms'} = join( "; ", $lineage_hash{'synonyms'}, $synonyms );
		} else {
			$lineage_hash{'synonyms'} = $synonyms;
		}

	}

	#set the "other" name
	my $real_rank = $nice_results->{Taxon}{Rank};
	if ( $real_rank eq 'no rank' ) {
		$lineage_hash{'other'} = $nice_results->{Taxon}{ScientificName};
	} elsif ( good_rank($real_rank) ) {
		$lineage_hash{$real_rank} = $nice_results->{Taxon}{ScientificName};
	}
	return ( $nice_results->{Taxon}{Lineage}, %lineage_hash );

}

#determines whether a certain taxonomy rank should be used
sub good_rank {
	my $rank = shift;
	if (   $rank eq 'superkingdom'
		|| $rank eq 'phylum'
		|| $rank eq 'class'
		|| $rank eq 'order'
		|| $rank eq 'family'
		|| $rank eq 'genus'
		|| $rank eq 'species' )
	{
		return 1;
	} else {
		return 0;
	}
}

sub get_file_type_list{
    my ($self,$dir,$file_name)=@_;
    my @all_files = glob($dir.'/'.$file_name."*");
    my @ext;
    foreach(@all_files){
	if(/$file_name(.+)/){
	    push @ext,$1;
	}
    }
    return join(" ",@ext);
}


1;

__END__

=head1 NAME

Parse: parses NCBI and custom flat files into MicrobeDB objects (when are then loaded into the database)

=head1 Synopsis

=head1 AUTHOR

Morgan Langille

=head1 Date Created

March, 2011

=cut



