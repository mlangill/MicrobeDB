#!/usr/bin/perl
#This is the main script for installing/updating MicrobeDB
#It acts as a wrapper to run 3 other scripts automatically (these can be run manually if you choose)
#1) All genomes are downloaded from NCBI using Aspera (default) or FTP (download_version.pl)
#2) Downloaded genomes are then extracted (unpack_version.pl)
#3) All genomes are parsed and loaded into microbedb (load_version.pl)
#4) Old versions in MicrobeDB are removed (note: custom version, saved versions, and last 2 most recent versions are never deleted)

#Note: This script can be set up in a cron job to run weekly/monthly/etc. Previous versions are left untouched and all data is re-downloaded, re-unpacked, and re-loaded into the database. Use "delete_version.pl" to remove these old versions.

#Author Morgan Langille, http://morganlangille.com

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl;
use Cwd qw(abs_path getcwd);
use Time::localtime;

my $prefix = 'Bacteria';

my ($download_parent_dir,$logger_cfg,$help,$parallel);;
my $res = GetOptions("directory=s" => \$download_parent_dir,
		     "parallel:i"=>\$parallel,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    );

my $usage = "Usage: $0 [-p <num_cpu>][-l <logger.conf>] [-h] -d directory \n";
my $long_usage = $usage.
    "Options:
-d or --directory <directory> : Mandatory. A directory where genomes will be downloaded and stored (e.g. ~/ncbi_genomes) 
-p or --parallel: Using this option without a value will use all cpus, while giving it a value will limit to that many cpus. Without option only one cpu is used. 
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";
die $long_usage if $help;

die $usage unless $download_parent_dir;


my $cpu_count=1;

#if the option is set
if(defined($parallel)){
    #option is set but with no value then use the max number of proccessors
    if($parallel ==0){
	$cpu_count=$ENV{NUMBER_OF_PROCESSORS};
    }else{
	$cpu_count=$parallel;
    }
}


# Clean up the download path
$download_parent_dir .= '/' unless $download_parent_dir =~ /\/$/;

# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);

# Set the logger config to a default if none is given
$logger_cfg = "$path/logger.conf" unless($logger_cfg);
# Set some base logging settings if the logger conf doesn't exist
$logger_cfg = q/
    log4perl.rootLogger = INFO, Screen

    log4perl.appender.Screen                          = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout.ConversionPattern = [%p] (%F line %L) %m%n
/ unless(-f $logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

$logger->fatal("$download_parent_dir is not a valid directory. Please supply a directory where NCBI flat files can be stored.") unless -d $download_parent_dir;
die "$download_parent_dir is not a valid directory. Please supply a directory where NCBI flat files can be stored." unless -d $download_parent_dir;

$logger->debug("Path to script is: $path");

$logger->info("Running script download_load_delete_old_version.pl\n");
$logger->info("Downloading all genomes from NCBI.(this takes a awhile, ~2-4hours)\n");

# Make the new download directory where this version will go
my $cur_time = localtime;
my ( $DAY, $MONTH, $YEAR ) = ( $cur_time->mday, $cur_time->mon + 1, $cur_time->year + 1900 );
if ( $DAY < 10 )   { $DAY   = '0' . $DAY; }
if ( $MONTH < 10 ) { $MONTH = '0' . $MONTH; }
my $download_dir = $download_parent_dir . "$prefix\_$YEAR\-$MONTH\-$DAY";
$logger->info("Making download dir $download_dir");
`mkdir $download_dir` unless -d $download_dir;
`mkdir $download_dir/log` unless -d "$download_dir/log";

#Download all genomes from NCBI
$logger->info("Download all genomes using download_version");
my $cmd = "$path/download_version.pl -d $download_dir";
$cmd .= " -l $logger_cfg" if(-f $logger_cfg);
system($cmd);
if($?) {
    $logger->fatal("Error with downloading the new version: $!");
    die;
}

$logger->info("Moving symlink for parent directory");
unlink "$download_parent_dir/$prefix" if ( -l "$download_parent_dir/$prefix");
symlink "$download_dir", "$download_parent_dir/$prefix" or $logger->error("Unable to create symlink from $download_dir to $download_parent_dir/$prefix\n");

$logger->info("Finished downloading genomes from NCBI.\n");

#unpack genome files
$logger->info("Unpacking genome files");
print "Unpacking genome files\n\n";
my $unpack_cmd="$path/unpack_version.pl -l logger.conf -d $download_dir";
if(defined($parallel)){
    $unpack_cmd .=" -p $cpu_count";
}

system($unpack_cmd);
if($?) {
    $logger->fatal("Error when unpacking the new version: $!");
    die;
}
print "Finished unpacking genome files\n\n";

#Load all genomes into microbedb as a new version
$logger->info("Parsing and loading each genome into NCBI");
print "Parsing and loading each genome into NCBI \n";
my $load_cmd = "$path/load_version.pl -l logger.conf -d $download_dir";
if(defined($parallel)){
    $load_cmd .=" -p $cpu_count";
}

system($load_cmd);
if($?) {
    $logger->fatal("Error loading the new version: $!");
    die;
}

print "Finished parsing and loading each genome into NCBI \n\n";
$logger->info("Finished parsing and loading each genome into NCBI");

#Remove old versions from MicrobeDB
$logger->info("Old versions in MicrobeDB are being deleted (note: the custom version, saved versions, and last 2 most recent versions are never deleted)");
system("$path/delete_version.pl -a -l logger.conf");
if($?) {
    $logger->fatal("Error cleaning up old versions of MicrobeDB: $!");
    die;
}

$logger->info("Finished deleting old versions of MicrobeDB");
