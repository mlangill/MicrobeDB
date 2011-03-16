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


	



