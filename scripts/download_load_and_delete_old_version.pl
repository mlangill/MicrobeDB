#!/usr/bin/perl
#This is the main script for installing/updating MicrobeDB
#It acts as a wrapper to run 3 other scripts automatically (these can be run manually if you choose)
#1) All genomes are downloaded from NCBI using Aspera (default) or FTP (download_version.pl)
#2) Downloaded genomes are then extracted (unpack_version.pl)
#3) All genomes are parsed and loaded into microbedb (load_version.pl)

#Note: This script can be set up in a cron job to run weekly/monthly/etc. Previous versions are left untouched and all data is re-downloaded, re-unpacked, and re-loaded into the database. Use "delete_version.pl" to remove these old versions.

#Author Morgan Langille, http://morganlangille.com

use strict;
use warnings;

#Please update the following variables
my $download_parent_dir =$ARGV[0];

die "$download_parent_dir is not a valid directory. Please supply a directory where NCBI flat files can be stored." unless -d $download_parent_dir;

print "Running script download_load_delete_old_version.pl\n";
print "Downloading all genomes from NCBI.(this takes a awhile, ~2-4hours)\n";

#Download all genomes from NCBI
my $download_dir_plus_crap = `./download_version.pl $download_parent_dir`;
my @crap = split(/\n/,$download_dir_plus_crap);
my $download_dir=$crap[-1];
chomp($download_dir);

print "Finished downloading genomes from NCBI.\n\n";

die "The download directory does not exist: $download_dir\nSomething wrong with download?\n" unless -d $download_dir;

#unpack genome files
print "Unpacking genome files\n\n";
system("./unpack_version.pl $download_dir");
print "Finished unpacking genome files\n\n";

#Load all genomes into microbedb as a new version
print "Parsing and loading each genome into NCBI \n";
system("./load_version.pl $download_dir");

print "Finished parsing and loading each genome into NCBI \n\n";

