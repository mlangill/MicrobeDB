#!/usr/bin/perl

#Copyright (C) 2011 Morgan G.I. Langille
#Author contact: morgan.g.i.langille@gmail.com

#This file is part of MicrobeDB.

#MicrobeDB is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#MicrobeDB is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with MicrobeDB.  If not, see <http://www.gnu.org/licenses/>.

#This script loads a single genome into an existing version of MicrobeDB.
#Useful if loading of a single genome failed during entire version load from NCBI downloads or a single custom genome is to be added. 
#Version must be specified. 

#*Note: load_version.pl should be used for loading an entire directory of NCBI genomes or custom genomes.

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl;
use Cwd qw(abs_path getcwd);
use File::Basename;
BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

#relative link to the api
use lib "../../";
use MicrobeDB::FullUpdate;
use MicrobeDB::Search;
use MicrobeDB::Parse;

my ($dir,$logger_cfg,$help);
my $res = GetOptions("directory=s" => \$dir,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    );

my $usage = "Usage: 
$0 [-l <logger config file>] [-h] -d directory \n";

my $long_usage = $usage.
    "-d or --directory <directory> : A directory of a genome to be loaded into MicrobeDB.
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";
die $long_usage if $help;

die $usage unless $dir;


# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

# Clean up the genome path
$dir .= '/' unless $dir =~ /\/$/;

my $so= new MicrobeDB::Search();

#Figure out what version this directory belongs to.       	
my $version_dir = dirname($dir);
$version_dir .= '/' unless $version_dir =~ /\/$/;

my ($version)=$so->table_search('version',{dl_directory=>$version_dir});
die "Can't figure out which version to load this genome into since directory: $version_dir is not in the version table" unless $version;

my $version_id=$version->{version_id};
my $up_obj = new MicrobeDB::FullUpdate( version_id=>$version_id );
$logger->info("Working on $dir");
	    
eval {
    
    #Parse the data and get the data structure
    my $parse =new MicrobeDB::Parse();
    my $gpo = $parse->parse_genome($dir);
    
    #pass the object to FullUpdate to do the database stuff
    $up_obj->update_genomeproject($gpo);
};

#if there was a parsing problem, give a warning and skip to the next genome project
if ($@) {
    warn "Couldn't add the following to microbedb: $dir ! Reason: $@";
    $logger->error("Couldn't add the following to microbedb: $dir ! Reason: $@");
    next;
}
	



