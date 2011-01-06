package NCBITOhash;

use strict;

use navigator;
use Data::Dumper;
use File::Basename;
use Bio::SeqIO;
use Carp;

#key = 'target fields' and value = 'source fields'
my %mapping = (
	"genomeproject|org_name"      => "gbk|taxon_name",
	"genomeproject|taxon_id"      => "gbk|taxon_id",
	"genomeproject|gp_id"         => "ncbi_orginf|Project ID",
	"genomeproject|lineage"       => "gpt|lineage",
	"genomeproject|gram_stain"    => "ncbi_orginf|Gram Stain",
	"genomeproject|genome_gc"     => "ncbi_comp|GC Content",
	"genomeproject|patho_status"  => "sub|deter_patho",
	"genomeproject|disease"       => "ncbi_orginf|Disease",
	"genomeproject|genome_size"   => "ncbi_comp|Genome Size",
	"genomeproject|pathogenic_in" => "ncbi_orginf|Pathogenic in",
	"genomeproject|temp_range"    => "ncbi_orginf|Temp. range",
	"genomeproject|habitat"       => "ncbi_orginf|Habitat",
	"genomeproject|shape"         => "ncbi_orginf|Shape",
	"genomeproject|arrangement"   => "ncbi_orginf|Arrangment",
	"genomeproject|endospore"     => "ncbi_orginf|Endospores",
	"genomeproject|motility"      => "ncbi_orginf|Motility",
	"genomeproject|salinity"      => "ncbi_orginf|Salinity",
	"genomeproject|oxygen_req"    => "ncbi_orginf|Oxygen Req",
	"genomeproject|release_date"  => "sub|get_releasedate",
	"genomeproject|centre"        => "ncbi_comp|List of Center/Consortium (pipe separated)",
	"replicon|rep_accnum"         => "rpt|Accession",
	"replicon|definition"         => "gbk|definition",
	"replicon|rep_type"           => "gbk|reptype",
	"replicon|rep_ginum"          => "rpt|GI",
	"replicon|file_name"          => "sub|gen_filename",
	"replicon|cds_num"            => "rpt|CDS count",
	"replicon|gene_num"           => "rpt|Gene count",
	"replicon|protein_num"        => "rpt|Protein count",
	"replicon|genome_id"          => "rpt|Genome_ID",
	"replicon|rep_size"           => "rpt|DNA  length",
	"replicon|rna_num"            => "rpt|RNA count",
	"replicon|file_types"         => "sub|dir_scan",
	"replicon|rep_seq"            => "fna|",
	"1gene|gid"                   => "gid",
	"1gene|pid"                   => "pid",
	"1gene|protein_accnum"        => "protein_accnum",
	"2gene|gene_type"             => "gene_type",
	"1gene|gene_start"            => "start",
	"1gene|gene_end"              => "end",
	"2gene|gene_length"           => "gene_length",
	"1gene|gene_strand"           => "strand",
	"1gene|gene_name"             => "gene_name",
	"1gene|locus_tag"             => "locus_tag",
	"1gene|gene_product"          => "product",
	"3gene|gene_seq"              => "gene_seq",
	"3gene|protein_seq"           => "protein_seq",
);

sub genomedata2hash {
	my %arg = @_;
	my $directory = $arg{'directory'} || die "no directory specified\n";
	my $parentdir;
	( $parentdir = $directory ) =~ s/(.+)\/.+\/?/$1/;
	my $NCBI_comp_genomes = $arg{'ncbi_comp'}
	  || "$parentdir/NCBI_completegenomes.txt";
	my $NCBI_org_info = $arg{'ncbi_org'} || "$parentdir/NCBI_orginfo.txt";

	#    my @req_filetypes = qw/gpt rpt fna gff faa ffn gbk/;
	my @req_filetypes  = qw/rpt fna faa ffn gbk/;
	my @optional_files = qw/frn gff/;

	my @files = get_allfiles_byext( $directory, @req_filetypes );
	die "File missing in directory: $directory"
	  unless ( ( ( scalar @files ) % ( scalar @req_filetypes ) == 0 )
		&& ( ( scalar @files ) != 0 ) );

	push( @files, get_allfiles_byext( $directory, @optional_files ) );

	my %file_hash;       #master hash to store all info extracted from files
	my $obj_hash_ref;    #converted to obj friendly hash

	my ( $base, $dir, $ext );
	foreach my $file (@files) {
		{
			( $base, $dir, $ext ) = fileparse( $file, '\..*' );
			$ext =~ s/\.//;
			no strict "refs";
			my $subroutine = "parse_" . $ext;

			#set up hash structure from file
			$file_hash{$base}{$ext} = &{$subroutine}($file);
		}
	}

	#get the ncbi org info and complete genome info for the replicons
	foreach my $acc ( keys %file_hash ) {
		my $taxid = $file_hash{$acc}{'gbk'}{'taxon_id'};
		$file_hash{$acc}{'ncbi_comp'} = &parse_ncbicompgenomefile( $NCBI_comp_genomes, $acc );
		$file_hash{$acc}{'ncbi_orginf'} = &parse_ncbiorginfofile( $NCBI_org_info, $taxid );
	}

	#uncomment next line to see the file hash results
	#print Dumper %file_hash;

	#setup genome project object-like hash
	$obj_hash_ref = &convert( \%file_hash, $dir );
	return $obj_hash_ref;

	#return 1;
}

sub parse_gff {
	
}

sub parse_gbk {
	my $file = shift;
	my %gbk_hash;



	#Decided to start using BioPerl to extract gene sequences
	my $in = Bio::SeqIO->new( -file => $file, -format => 'genbank' );
	while ( my $seq = $in->next_seq() ) {
		$gbk_hash{'definition'} = $seq->desc();
		$gbk_hash{'reptype'}    = &get_reptype( $gbk_hash{'definition'} );

		my @features = $seq->get_SeqFeatures();
		foreach my $feat (@features) {
			my $gene_type = $feat->primary_tag();
			if($gene_type eq 'source'){
				($gbk_hash{'taxon_name'})= $feat->has_tag('organism') ? $feat->get_tag_values('organism') : '';
				my @db_xref = $feat->has_tag('db_xref') ? $feat->get_tag_values('db_xref') : '';
				my $taxon_id;
				foreach (@db_xref) {
					if (/taxon:(\d+)/) {
						$taxon_id=$1;
					}
				}
				warn "Could not find taxon id!\n" unless $taxon_id;
				$gbk_hash{'taxon_id'}= $taxon_id;
			}
			next if $gene_type eq 'source';
			my $protein_seq = '';
			if ( $gene_type eq 'CDS' ) {
				
				if ( $feat->has_tag('translation') ) {
					($protein_seq) = $feat->get_tag_values('translation');
				} else {
					if ($feat->has_tag('pseudo')){
						#skip pseudogenes
						next;
					}else{
						warn "No translation available for CDS in taxon id: $gbk_hash{'taxon_id'}!\n";
					}

				}
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

			my %record = (
				'gene_type'      => $gene_type,
				'start'          => $start,
				'end'            => $end,
				'gene_length'		=> $gene_length,
				'strand'         => $strand,
				'product'        => $product,
				'gene_seq'       => $gene_seq,
				'protein_seq'    => $protein_seq,
				'gene_name'      => $gene_name,
				'locus_tag'      => $locus_tag,
				'protein_accnum' => $protein_accnum,
				'gid'            => $gid,
				'pid'            => $pid,
			);
			push @{ $gbk_hash{$gene_type} }, \%record;
		}

	}

	return \%gbk_hash;
}

sub parse_rpt {
	my $file = shift;
	my %hash_rpt;
	open( INFILE, $file ) or die "Can't not find file $file\n";
	while (<INFILE>) {
		if (/(.+)?[:=](.+)/) {
			my $key   = trim($1);
			my $value = trim($2);
			$hash_rpt{$key} = $value;
		}
	}
	close INFILE;
	return \%hash_rpt;
}

sub process_attributes {
	my $attr_string = shift;
	my @attributes = split( /\;/, $attr_string );
	my %attr;
	foreach (@attributes) {
		my $att_string = &URLDecode($_);
		my ( $key, $value ) = split /=/, $att_string;

		#Added MultiFun requirement
		#if ($value=~/\:/ && !($value =~ /MultiFun/)){
		if ( $att_string =~ /db_xref\=.*\:/ ) {
			my ( $subkey, $subvalue ) = split( /:/, $value );
			$attr{$key}{$subkey} = $subvalue;
		} else {
			$attr{$key} = $value;
		}
	}
	return \%attr;
}

sub parse_ncbicompgenomefile {
	my $complete_genome_file = shift;
	my $accession            = shift;
	open( COMPFILE, $complete_genome_file )
	  or die "Can't find the Complete Genome file - $complete_genome_file\n";
	my @headings;
	my %comp_org_parse;
	while (<COMPFILE>) {
		chomp;
		if (/^## Columns:\s+(.+)$/) {
			@headings = split( /\t/, $1 );
			my $numof_fields = scalar(@headings);
			for ( my $cnum = 0 ; $cnum <= $numof_fields ; $cnum++ ) {
				$headings[$cnum] =~ s/^"(.+)"$/$1/;
			}
		} elsif (/^\d+\s+\w+/) {
			my @entries = split(/\t/);
			if ( scalar(@entries) != scalar(@headings) ) {

				#warning here
			}
			#Note: this hardcoded value is not very good!!
			my @accessions = split( /,/, $entries[13] );
			foreach (@accessions) {
				if ( $accession eq $_ ) {
					my $i = 0;
					foreach (@entries) {
						$comp_org_parse{ $headings[$i] } = $_;
						$i++;
					}
				}
			}
		} else {
			next;
		}
	}

	return \%comp_org_parse;
}

sub parse_ncbiorginfofile {
	my $org_info_file = shift;
	my $taxid         = shift;
	my @headings;
	my %info_org_parse;
	open( INFOFILE, $org_info_file )
	  or die "Can't find the ORGINFO file - $org_info_file\n";
	while (<INFOFILE>) {
		chomp;
		if (/^\#\# Columns:\s+(.+)$/) {
			@headings = split( /\t/, $1 );
			my $numof_fields = scalar(@headings);
			for ( my $cnum = 0 ; $cnum < $numof_fields ; $cnum++ ) {
				$headings[$cnum] =~ s/^"(.+)"$/$1/;
			}
		} elsif (/^\d+\s+\w+/) {
			my @entries = split(/\t/);
			my $i;
			if ( scalar(@entries) != scalar(@headings) ) {

				#carp "Some problem parsing ncbi org file\n";
			}
			if ( $entries[2] == $taxid ) {
				foreach (@entries) {
					$info_org_parse{ $headings[$i] } = $_;
					$i++;
				}
			}
		} else {
			next;
		}
	}

	return \%info_org_parse;
}

sub parse_ffn_old {
	my $file = shift;
	my %ffn_hash;
	local $/ = '>';
	open( INFILE, $file ) or die "Cannot find file $file\n";
	while (<INFILE>) {
		my $coor = '';
		my $seq  = '';
		if (/.+?:c(\d+)\-(\d+)(.+)>/s) {
			my $start = $2;
			my $end   = $1;
			$coor = "$start-$end";
			$seq  = trim($3);
		} elsif (/.+?:(\d+)\-(\d+)(.+)>/s) {
			my $start = $1;
			my $end   = $2;
			$coor = "$start-$end";
			$seq  = trim($3);
		} else {
			next;
		}
		$ffn_hash{$coor} = $seq;
	}
	return \%ffn_hash;
}

sub parse_frn {
	my $file = shift;
	my %ffn_hash;

	open( INFILE, $file ) or die "Cannot find file $file\n";
	my $count = -1;
	my @coords;
	my @seqs;
	while (<INFILE>) {

		if (/^>/) {
			$count++;
			if (/:c(\d+)\-(\d+)/) {
				my $start = $2;
				my $end   = $1;
				$coords[$count] = "$start-$end";
			} elsif (/:(\d+)\-(\d+)/) {
				my $start = $1;
				my $end   = $2;
				$coords[$count] = "$start-$end";
			}
		} elsif (/([A-Za-z]+)/) {
			$seqs[$count] .= $1;
		}
	}

	for ( my $i = 0 ; $i < @seqs ; $i++ ) {
		$ffn_hash{ $coords[$i] } = $seqs[$i];
	}

	return \%ffn_hash;
}

sub parse_ffn {
	my $file = shift;
	my %ffn_hash;

	open( INFILE, $file ) or die "Cannot find file $file\n";
	my $count = -1;
	my @coords;
	my @seqs;
	while (<INFILE>) {

		if (/^>/) {
			$count++;
			if (/:c(\d+)\-(\d+)/) {
				my $start = $2;
				my $end   = $1;
				$coords[$count] = "$start-$end";
			} elsif (/:(\d+)\-(\d+)/) {
				my $start = $1;
				my $end   = $2;
				$coords[$count] = "$start-$end";
			}
		} elsif (/([A-Za-z]+)/) {
			$seqs[$count] .= $1;
		}
	}

	for ( my $i = 0 ; $i < @seqs ; $i++ ) {
		$ffn_hash{ $coords[$i] } = $seqs[$i];
	}

	return \%ffn_hash;
}

sub parse_faa {
	my $file = shift;
	my %faa_hash;

	open( INFILE, $file ) or die "Cannot find file $file\n";
	my $count = -1;
	my @gis;
	my @seqs;
	while (<INFILE>) {
		if (/^>/) {
			$count++;
			if (/gi\|(\d+).+/) {
				$count++;
				$gis[$count] = $1;
			}
		} elsif (/([A-Za-z]+)/) {
			$seqs[$count] .= $1;
		}
	}
	for ( my $i = 0 ; $i < @seqs ; $i++ ) {
		$faa_hash{ $gis[$i] } = $seqs[$i];
	}
	return \%faa_hash;
}

sub parse_faa_old {
	my $file = shift;
	my %faa_hash;
	local $/ = '>';
	open( INFILE, $file ) or die "Cannot find file $file\n";
	while (<INFILE>) {
		if (/gi\|(\d+).+?\n(.+)>/s) {
			my $gi  = $1;
			my $seq = trim($2);
			$faa_hash{$gi} = $seq;
		}
	}
	return \%faa_hash;
}

sub parse_fna {
	my $file = shift;
	my %fna_hash;
	my $accnum = '';
	my $seq    = '';
	open( INFILE, $file ) or die "Cannot find file $file\n";
	while (<INFILE>) {
		if (/^>.*ref\|(\w\w\_\d+)(\.\d+)?\|/) {
			$accnum = $1;
		} else {
			$seq = $seq . $_;
		}
	}
	$seq = trim($seq);
	$fna_hash{$accnum} = $seq;    #TODO may be good to return a hash in context
	return $seq;
}

sub parse_gpt {
	my $file = shift;
	local $/ = undef;
	open( INFILE, $file ) or die "Cannot find file $file\n";
	my $gptext = <INFILE>;
	my %gpt_hash;
	if ( $gptext =~ /^Lineage\:\n(.+)Genome\s+Projects/sm ) {
		$gpt_hash{'lineage'} = &trim($1);
	}
	if ( $gptext =~ /^\s+Genome\s+sequencing\:\n(.+)\(Project\sID\:\s+(\d+)\).+Genome\s+information\:/sm ) {
		$gpt_hash{'gp_id'} = &trim($2);
	}
	return \%gpt_hash;
}

sub convert {
	my $file_hash_ref = shift;
	my $dir           = shift;
	my %obj_hash;
	my @gpj_fields  = grep { /^genomeproject/ } keys %mapping;
	my @rep_fields  = grep { /^replicon/ } keys %mapping;
	my @gene_fields = grep { /^\dgene/ } keys %mapping;
	@gene_fields = sort @gene_fields;

	#print @gene_fields;
	my @rep_accessions = keys %$file_hash_ref;
	my $repcount       = 0;
	my $genecount      = 0;
	foreach my $acc (@rep_accessions) {
		next if ( $acc =~ /ncbi/ );
		foreach (@gpj_fields) {
			my @targetfields = split /\|/, $_;
			my @sourcefields = split /\|/, $mapping{$_};
			my $sourcevalue  = $file_hash_ref->{$acc};
			for ( my $i = 0 ; $i <= $#sourcefields ; $i++ ) {
				if ( $sourcefields[$i] eq 'sub' ) {
					my $subroutine = $sourcefields[ $i + 1 ];
					{
						no strict "refs";
						$sourcevalue = &{$subroutine}( $file_hash_ref, $acc );
					}
					last;
				} else {
					$sourcevalue = $sourcevalue->{ $sourcefields[$i] };
				}
			}
			$obj_hash{ $targetfields[1] } = $sourcevalue;
		}
		foreach (@rep_fields) {
			my @targetfields = split /\|/, $_;
			my @sourcefields = split /\|/, $mapping{$_};
			my $sourcevalue  = $file_hash_ref->{$acc};
			for ( my $i = 0 ; $i <= $#sourcefields ; $i++ ) {
				if ( $sourcefields[$i] eq 'sub' ) {
					my $subroutine = $sourcefields[ $i + 1 ];
					{
						no strict "refs";
						$sourcevalue = &{$subroutine}( $file_hash_ref, $acc, $dir );
					}
					last;
				} else {
					$sourcevalue = $sourcevalue->{ $sourcefields[$i] };
				}
			}

			#$obj_hash{'replicon'}{$acc}{$targetfields[1]}=$sourcevalue;
			#push @{$obj_hash{'replicon'}}, {$targetfields[1] => $sourcevalue};
			$obj_hash{'replicons'}[$repcount]{ $targetfields[1] } = $sourcevalue;
		}
		my $gene_array;
		for(qw(CDS tRNA rRNA ncRNA misc_RNA tmRNA)){
			if ( exists( $file_hash_ref->{$acc}{gbk}{$_} ) ) {
				push @$gene_array, @{ $file_hash_ref->{$acc}{gbk}{$_} };
			}
		}
		
		foreach my $gene (@$gene_array) {
			foreach (@gene_fields) {
				my $sourcevalue  = $gene;
				my @targetfields = split /\|/, $_;
				my @sourcefields = split /\|/, $mapping{$_};
				for ( my $i = 0 ; $i <= $#sourcefields ; $i++ ) {
					if ( $sourcefields[$i] eq 'sub' ) {
						my $subroutine = $sourcefields[ $i + 1 ];
						{
							no strict "refs";
							$sourcevalue =
							  &{$subroutine}( $obj_hash{'replicons'}[$repcount]{'genes'}[$genecount], $file_hash_ref,
								$acc, $gene );
						}
						last;
					} else {
						$sourcevalue = $sourcevalue->{ $sourcefields[$i] };
					}
				}

				#$obj_hash{'replicon'}{$acc}{$targetfields[1]}=$sourcevalue;
				#push @{$obj_hash{'replicon'}{'genes'}}, {$targetfields[1] => $sourcevalue};
				#a quick hack to solve the genename issue where the gene
				#name is returned as a hash coupled to the replicon accnum
				#so we check to see if a hash ref is returned, discard the
				#key and keep only the value
				if ( ref($sourcevalue) eq 'HASH' ) {
					my @values = values(%$sourcevalue);
					$sourcevalue = shift @values;
				}

				#Another hack to try to get the correct gene_name
				if (   $targetfields[1] eq 'gene_name'
					&& $sourcevalue =~ /\:(\w+)\:/ )
				{
					$sourcevalue = $1;
				}

				$obj_hash{'replicons'}[$repcount]{'genes'}[$genecount]{ $targetfields[1] } = $sourcevalue;
			}
			$genecount++;
		}
		$repcount++;
		$genecount = 0;
	}
	return \%obj_hash;
}

###General Subroutines
sub URLDecode {
	my $theURL = shift;
	$theURL =~ tr/+/ /;
	$theURL =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
	$theURL =~ s/<!--(.|\n)*-->//g;

	#Morgan Hack: I don't like unscores instead of spaces in the gene product fields
	#$theURL =~ s/\s/_/g;
	return $theURL;
}

sub trim {
	my $string = shift;
	$string =~ s/\n+//g;
	$string =~ s/^\s+//g;
	$string =~ s/\s+$//g;
	return $string;
}

sub get_releasedate {
	my $file_hash_ref = shift;
	my $accession     = shift;
	my $release_date  = $file_hash_ref->{$accession}{'ncbi_comp'}{'Released date'};
	my ( $month, $day, $year ) = split /\//, $release_date;
	$day   =~ s/(\d)/0$1/ if ( $day   =~ /^\d$/ );
	$month =~ s/(\d)/0$1/ if ( $month =~ /^\d$/ );
	return ("$year-$month-$day");
}

sub get_reptype {
	my $orgdesc = shift;
	my $reptype;
	if ( $orgdesc =~ /plasmid/i ) {
		$reptype = 'plasmid';
	} else {
		$reptype = 'chromosome';
	}
	return $reptype;
}

sub deter_patho {
	my $file_hash_ref = shift;
	my $accession     = shift;
	my $pathogenic_in = $file_hash_ref->{$accession}{'ncbi_orginf'}{'Pathogenic in'};
	my $result;
	if ( $pathogenic_in eq 'No' ) {
		$result = 'nonpathogen';
	} elsif ( $pathogenic_in =~ /^\s*$/ ) {
		$result = 'unknown';
	} else {
		$result = 'pathogen';
	}
	return $result;
}

sub gen_filename {
	my $file_hash_ref = shift;
	my $orgname       = $file_hash_ref->{'org_name'};
	my $accession     = shift;
	my @elements      = split /\s/, $orgname;
	my $genus         = $elements[0];
	my $species       = $elements[1];

	#The following was Will's code but the $genus and $species variable was not being set,
	#  so I have changed the filename to have the accession number (without the version)
	#my $filename  = substr( $genus, 0, 2 ). substr( $species, 0, 3 ). substr( $accession, 3 );
	#$filename =~ s/\.//;

	#my new code
	my $filename = $accession;

	return $filename;
}

sub dir_scan {
	my $file_hash_ref = shift;
	my $accession     = shift;
	my $dir           = shift;
	my @ext;
	my @files = get_allfiles_byname( $dir, $accession );
	foreach (@files) {
		my ( $base, $dir, $ext ) = fileparse( $_, '\..*' );
		push @ext, $ext;
	}
	return "@ext";
}

sub get_gene_type {
	my $gene_hash_ref = shift;
	my $file_hash_ref = shift;
	my $acc           = shift;
	my $gene          = shift;

	my $gene_type;
	if ( exists( $gene->{attribute}{gbkey} ) ) {
		$gene_type = $gene->{attribute}{gbkey};
	} else {
		$gene_type = 'CDS';
	}
	return $gene_type;
}

sub cal_gene_length {
	my $gene_hash_ref = shift;
	my $gene_start    = $gene_hash_ref->{'gene_start'};
	my $gene_end      = $gene_hash_ref->{'gene_end'};
	my $length        = ( $gene_end - $gene_start ) + 1;
	return $length;
}

sub get_prot_seq {
	my $gene_hash_ref = shift;
	my $file_hash_ref = shift;
	my $acc           = shift;
	my $pid           = $gene_hash_ref->{'pid'};
	my $seq           = $file_hash_ref->{$acc}{'faa'}{$pid};
	if ( !$seq ) {
		my $debug;
	}
	return $seq;
}

sub get_gene_seq {
	my $gene_hash_ref = shift;
	my $file_hash_ref = shift;
	my $acc           = shift;
	my $strand        = $gene_hash_ref->{'gene_strand'};
	my $gene_start    = $gene_hash_ref->{'gene_start'};
	my $gene_end      = ( $gene_hash_ref->{'gene_end'} );

	my $seq;
	if ( $gene_hash_ref->{gene_type} eq 'CDS' ) {

		#short term solution for accounting for the discrepancy between
		#the CDS start and the gene start site which include the start codon
		if ( $strand eq '-' ) {
			$gene_start = $gene_start - 3;
		} else {
			$gene_end = $gene_end + 3;
		}
		my $coor = "$gene_start-$gene_end";

		$seq = $file_hash_ref->{$acc}{'ffn'}{$coor};

		#in the rare case we don't find the sequence then try searching for it.
		unless ( defined($seq) ) {
			foreach my $coor ( keys %{ $file_hash_ref->{$acc}{'ffn'} } ) {
				my ( $start, $end ) = split( /-/, $coor );
				if ( $start == $gene_start || $end == $gene_end ) {
					$seq = $file_hash_ref->{$acc}{'ffn'}{$coor};
					last;
				}
			}
		}
	} else {
		my $coor = "$gene_start-$gene_end";
		$seq = $file_hash_ref->{$acc}{'frn'}{$coor};
	}

	#print $coor, ":", $seq, "\n";
	if ( !$seq ) {
		my $debug;

		#warn "\ncoor:$coor\n";
		#warn Dumper $file_hash_ref->{$acc}{'ffn'};

	}
	return $seq;
}

1;
