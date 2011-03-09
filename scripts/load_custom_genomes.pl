#!/usr/bin/perl
#This script loads custom genomes (ones not downloaded from NCBI, but instead provided by the user)

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
use Time::localtime;
use Time::Local;
use File::stat;
use Getopt::Long;
use LWP::Simple;
use Log::Log4perl;
use Cwd qw(abs_path getcwd);

BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

#relative link to the api
use lib "../../";
use lib "./";
use MicrobeDB::FullUpdate;
use MicrobeDB::Search;
use MicrobeDB::Parse;
 
use XML::Simple;
use LWP::Simple;

my ($download_dir,$logger_cfg,$custom);
my $res = GetOptions("directory=s" => \$download_dir,
		     "logger=s" => \$logger_cfg,
		     "custom"=>\$custom,
    );

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;

unless ( $download_dir && -d $download_dir) {
	print "Input the directory containing your custom genomes\n";
	$logger->fatal("Download directory not valid: $download_dir");
	exit;
}

#Load the genome into microbedb as a custom genome (version_id==0)
my $new_version = load_microbedb($download_dir);

sub load_microbedb {
	my ($dl_dir) = @_;

	my $up_obj;
	#custom genome
	if($custom){
	    $up_obj = new MicrobeDB::FullUpdate( dl_directory => $dl_dir, version_id=>0 );
	}else{
	    $up_obj = new MicrobeDB::FullUpdate( dl_directory => $dl_dir);
	}
	#do a directory scan
	my @genome_dir = get_sub_dir($dl_dir);
	
	my $so = new MicrobeDB::Search();
	foreach my $curr_dir (@genome_dir) {
	    $logger->info("Working on $curr_dir");
	    
	    eval {
		
		#Parse the data and get the data structure
		my $parse =new MicrobeDB::Parse();
		my $gpo = $parse->parse_genome($curr_dir);
    		
		#pass the object to FullUpdate to do the database stuff
		$up_obj->update_genomeproject($gpo);
	    };
	    
	    #if there was a parsing problem, give a warning and skip to the next genome project
	    if ($@) {
		warn "Couldn't add the following to microbedb: $curr_dir ! Reason: $@";
		$logger->error("Couldn't add the following to microbedb: $curr_dir ! Reason: $@");
		next;
	    }
	    
	}
	
	return $up_obj->version_id();

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

