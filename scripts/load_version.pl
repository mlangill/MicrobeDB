#!/usr/bin/perl
#All genomes are parsed and loaded into microbedb

#Author Morgan Langille
#Last updated: see svn

use strict;
use warnings;
use Time::localtime;
use Time::Local;
use File::stat;
use Getopt::Long;
use LWP::Simple;

#relative link to the api
use lib "../../";
use lib "./";
use MicrobeDB::FullUpdate;
use NCBITOhash;
use MicrobeDB::Search;

use XML::Simple;
use LWP::Simple;


my $download_dir = $ARGV[0];
unless ( $download_dir && -d $download_dir ) {
	print "Input the directory containing the downloaded organisms from NCBI.\n";
	exit;
}

#Load all genomes into microbedb as a new version (note unused versions are deleted before this load is done)
my $new_version = load_microbedb($download_dir);

sub load_microbedb {
	my ($dl_dir) = @_;
	my $up_obj = new MicrobeDB::FullUpdate( dl_directory => $dl_dir );

	#do a directory scan
	my @genome_dir = get_sub_dir($dl_dir);
	
	my $so = new MicrobeDB::Search();
	foreach my $curr_dir (@genome_dir) {
	    print "$curr_dir \n";
	    my $data_hash;
	    
	    eval {
		
		#Call Will's script to parse the data and get the data structure
		$data_hash = NCBITOhash::genomedata2hash( directory => $curr_dir );
		my $gpo      = new MicrobeDB::GenomeProject(%$data_hash);
		my $taxon_id = $gpo->taxon_id;
		my ($taxon)    = $so->table_search( 'taxonomy', { taxon_id => $taxon_id } );
		#set the 
		unless ( $taxon && $taxon->{'superkindom'} ) {
		    eval {
			my ( $lineage, %lineage_full ) = get_taxonomy( $gpo->taxon_id );
			
			#Set the lineage information into our massive hash
			$gpo->lineage($lineage);
			
			#put the taxonomy annotations into the genome project object
			foreach ( keys(%lineage_full) ) {
			    $gpo->$_( $lineage_full{$_} );
			}
		    };
		    if ($@) {
			warn
			    "Couldn't retrieve taxon information from NCBI for taxon id:$taxon_id. Lineage fields will not be filled for $curr_dir ";
		    }
		}
		
		#Set the gp directory
		$gpo->gpv_directory($curr_dir);
		
		#pass the object to FullUpdate to do the database stuff
		$up_obj->update_genomeproject($gpo);
	    };
	    
	    #if there was a parsing problem, give a warning and skip to the next genome project
	    if ($@) {
		warn "WARNING, Couldn't add the following to microbedb: $curr_dir \nReason: $@\n";
		next;
	    }
	    
	}
	
	#check the updatelog for any manual changes that need to be made
	#manual_changes($up_obj);
	
	return $up_obj->version_id();

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
	my $xml          = new XML::Simple;
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

sub get_sub_dir {
	my $head_dir = shift;
	unless ( $head_dir =~ /\/$/ ) {
		$head_dir .= '/';
	}

	my @dir = `ls -d $head_dir*/`;
	chomp(@dir);
	return remove_dir(@dir);
}

#removes any directories that does not contain a genome project (or causes other problems)
sub remove_dir {
	my @genome_dir = @_;
	my @temp;

	#Filter out some directories we don't want
	foreach (@genome_dir) {
		next if ( $_ =~ /CLUSTERS/ );

		push( @temp, $_ );
	}
	return @temp;
}

