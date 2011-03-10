#!/usr/bin/perl
#This script reloads a single genome into an existing version of MicrobeDB.
#Useful if loading of a single genome failed during entire version load from NCBI downloads. 
#Version must be specified along with download directory. 

#Note*: This is the same as using add_genome.pl and delete_genome.pl 
#Note*: Any microbedb ids (gpv_id, rpv_id,gv_id) are not conserved.

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
use Getopt::Long;
use Cwd qw(abs_path getcwd);

my $path;
BEGIN{
# Find absolute path of script
($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

my ($dir,$logger_cfg,$help);
my $res = GetOptions("directory=s" => \$dir,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    );

my $usage = "Usage: 
$0 [-l <logger config file>] [-h] -d directory \n";

my $long_usage = $usage.
    "-d or --directory <directory> : Mandatory. A directory of a genome already loaded in MicrobeDB.
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";
die $long_usage if $help;

die $usage unless $dir;


# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);

my $delete_cmd=$path.'/delete_genome.pl'." -l $logger_cfg -d $dir";
#delete old one
system($delete_cmd);

#add new one
system($path.'/load_genome.pl'." -l $logger_cfg -d $dir");


	



