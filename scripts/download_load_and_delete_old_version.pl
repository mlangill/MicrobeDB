#!/usr/bin/perl
#This script is run monthly and keeps microbedb up to date
#1) All genomes are downloaded from NCBI using wget (download_version.pl)
#2) All genomes are parsed and loaded into microbedb (load_version.pl)


#Author Morgan Langille 
#Last updated: see svn

use strict;
use warnings;

#Please update the following variables
my $download_parent_dir =$ARGV[0];

die "$download_parent_dir is not a valid directory. Please supply a directory where NCBI flat files can be stored." unless -d $download_parent_dir;

print "Running script download_load_delete_old_version.pl\n";
print "Downloading all genomes from NCBI.(this takes a awhile, ~2-4hours)\n";

#Download all genomes from NCBI
my $download_dir = `./download_version.pl $download_parent_dir`;
chomp($download_dir);

print "Finished downloading genomes from NCBI.\n\n";

die "The download directory does not exist: $download_dir\nSomething wrong with ftp download?\n" unless -d $download_dir;

#unpack genome files
print "Unpacking genome files\n\n";
system("./unpack_version.pl $download_dir");
print "Finished unpacking genome files\n\n";

#Load all genomes into microbedb as a new version (note unused versions are deleted before this load is done)
print "Parsing and loading each genome into NCBI \n";
system("./load_version.pl $download_dir");

print "Finished parsing and loading each genome into NCBI \n\n";

