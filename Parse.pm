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

sub parse_custom_genome{
    my ($self,$dir)=@_;

    my $gpo=$self->gpo();
    $gpo->gpv_directory($dir);

    my @files = glob($dir.'/*');

    #get genbank files
    my @gbk_files = grep{/.gbk/i || /.genbank/i}@files;

    unless(@gbk_files){
	$logger->error("No genbank files found in directory: $dir");
	die ("No genbank files found in directory: $dir")
    }
    foreach my $file_name (@gbk_files){
	$self->parse_gbk($file_name);
    }
    
    if($gpo->taxon_id){
	$self->parse_taxonomy();
    }else{
	#use directory name for org_name in genomeproject
	$gpo->org_name(basename($dir));
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
    unless ( $taxon && $taxon->{'superkindom'} ) {
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
	    warn
		"Couldn't retrieve taxon information from NCBI for taxon id:$taxon_id.";
	    $logger->error("Couldn't retrieve taxon information from NCBI for taxon id:$taxon_id.");
	}
    }
}



sub parse_gbk {
	my ($self,$file) = @_;

	my $genome=$self->gpo();
	#Decided to start using BioPerl to extract gene sequences
	my $in = Bio::SeqIO->new( -file => $file, -format => 'genbank' );
	my ($file_name,$dir,$ext)=fileparse($file,qr/\.[^.]*/);
	while ( my $seq = $in->next_seq() ) {

	    #set stuff about the species
	    my $species = $seq->species();
	    if($species){
		my $taxon_id=$species->ncbi_taxid();
		$genome->taxon_id($taxon_id) if $taxon_id;
		my $taxon_name=$species->binomial('FULL');
		$genome->org_name($taxon_name) if $taxon_name;
	    }

	    #set stuff about the replicon
	    my $rep= new MicrobeDB::Replicon();
	    my $def = $seq->desc();
	    $rep->definition($def);
	    $rep->rep_size($seq->length());
	    $rep->rep_seq($seq->seq());
	    $rep->file_name($file_name);
	    $rep->file_types($ext);
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


#Retrieves taxon information from NCBI's website using Eutils
#Input: a NCBI taxon id
#Output: the lineage, and the full taxon
sub get_taxonomy {
	my ($taxon_id) = @_;
	my $eutil      = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?';
	my $email      = 'mlangill@sfu.ca';
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



