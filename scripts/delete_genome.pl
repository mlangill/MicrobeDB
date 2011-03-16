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


#This script deletes a single genome from an existing version of MicrobeDB.
#gpv_id  or the directory of the genome must be specified. 

#*Note: delete_version.pl should be used for removing an entire directory of NCBI genomes or custom genomes.

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
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
use MicrobeDB::Search;

my ($dir,$logger_cfg,$custom,$help,$version_id,$gpv_id);
my $res = GetOptions("directory=s" => \$dir,
		     "logger=s" => \$logger_cfg,
		     "version=i"=>\$version_id,
		     "gpv_id=i"=>\$gpv_id,
		     "custom"=>\$custom,
		     "help"=>\$help,
    );

my $usage = "Usage: 
$0 [-l <logger.conf>] [-h] -d <directory>
OR
$0 [-l <logger.conf>] [-h] -g <gpv_id>
";
my $long_usage = $usage.
    "-d or --directory <directory> : A directory of a genome already loaded in MicrobeDB.
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";

die $long_usage if $help;

die $usage unless $gpv_id || $dir;


# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;
 
my $so=new MicrobeDB::Search();
my $gpo;
if($gpv_id){
    ($gpo)= $so->object_search(new MicrobeDB::GenomeProject(gpv_id=>$gpv_id));
    die "Can't find gpv_id: $gpv_id in MicrobeDB" unless ($gpo);
    $logger->info("Removing genome,replicons, and genes associated with gpv_id: $gpv_id ");

}else{
    ($gpo)= $so->object_search(new MicrobeDB::GenomeProject(gpv_directory=>$dir));
    die "Can't find any genome with gpv_directory: $dir" unless ($gpo);
    $logger->info("Removing genome,replicons, and genes associated with directory: $dir ");

}

$gpo->delete();

	



