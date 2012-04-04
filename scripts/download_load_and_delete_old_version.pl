#!/usr/bin/env perl
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

#Author Morgan Langille, http://morganlangille.com

$|++;

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl;
use Cwd qw(abs_path getcwd);
use Pod::Usage;
use Time::localtime;

#Call some modules we don't need here but will need in other scripts being called.
use Parallel::ForkManager;
use Bio::SeqIO;

my $prefix = 'Bacteria';

my ($download_parent_dir,$logger_cfg,$help,$parallel,$special_download_options);
my $res = GetOptions("directory=s" => \$download_parent_dir,
		     "parallel:i"=>\$parallel,
		     "logger=s" => \$logger_cfg,
		     "special_download_options=s"=>\$special_download_options,
		     "help"=>\$help,
    )or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify your download directory.') unless defined $download_parent_dir;


# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);

# Set the logger config to a default if none is given
$logger_cfg = "$path/logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

my $cpu_count=0;
#if the option is set
if(defined($parallel)){
    #option is set but with no value then use the max number of proccessors
    if($parallel ==0){
	eval("use Sys::CPU;");
	$cpu_count=Sys::CPU::cpu_count();
    }else{
	$cpu_count=$parallel;
    }
}

# Clean up the download path
$download_parent_dir .= '/' unless $download_parent_dir =~ /\/$/;

$logger->logdie("$download_parent_dir is not a valid directory. Please supply a directory where NCBI flat files can be stored.") unless -d $download_parent_dir;

$logger->debug("Path to script is: $path");

$logger->debug("Running script download_load_delete_old_version.pl\n");

# Make the new download directory where this version will go
my $cur_time = localtime;
my ( $DAY, $MONTH, $YEAR ) = ( $cur_time->mday, $cur_time->mon + 1, $cur_time->year + 1900 );
if ( $DAY < 10 )   { $DAY   = '0' . $DAY; }
if ( $MONTH < 10 ) { $MONTH = '0' . $MONTH; }
my $download_dir = $download_parent_dir . "$prefix\_$YEAR\-$MONTH\-$DAY";
$logger->info("Making download directory: $download_dir");
`mkdir $download_dir` unless -d $download_dir;
`mkdir $download_dir/log` unless -d "$download_dir/log";

#Download all genomes from NCBI
$logger->info("Downloading all genomes from NCBI.(Downloading time will vary depending on your connection and how flaky NCBI is today; ~1-4hours)\n");
my $cmd = "$path/download_version.pl -d $download_dir $downloader_options";
$cmd .= " -l $logger_cfg" if(-f $logger_cfg);
system($cmd);
$logger->logdie("Error with downloading the new version: $!") if $?;


$logger->info("Finished downloading genomes from NCBI.\n");

#unpack genome files
$logger->info("Unpacking genome files");
my $unpack_cmd="$path/unpack_version.pl -l logger.conf -d $download_dir";
if(defined($parallel)){
    $unpack_cmd .=" -p $cpu_count";
}

system($unpack_cmd);
$logger->logdie("Error when unpacking the new version: $!") if $?;

$logger->info("Finished unpacking genome files");

#Load all genomes into microbedb as a new version
$logger->info("Parsing and loading each genome into NCBI");
my $load_cmd = "$path/load_version.pl -l logger.conf -d $download_dir";
if(defined($parallel)){
    $load_cmd .=" -p $cpu_count";
}
system($load_cmd);
$logger->logdie("Error loading the new version: $!") if $?;
  
$logger->info("Finished parsing and loading each genome into NCBI");

#Remove old versions from MicrobeDB
$logger->info("Old versions in MicrobeDB are being deleted (note: the custom version, saved versions, and last 2 most recent versions are never deleted)");
system("$path/delete_version.pl -a -l logger.conf");
$logger->logdie("Error cleaning up old versions of MicrobeDB: $!") if $?;

$logger->info("Moving symlink for parent directory");
unlink "$download_parent_dir/$prefix" if ( -l "$download_parent_dir/$prefix");
symlink "$download_dir", "$download_parent_dir/$prefix" or $logger->error("Unable to create symlink from $download_dir to $download_parent_dir/$prefix\n");

#All Done!
$logger->info("Finished deleting old versions of MicrobeDB");

__END__

=head1 Name

download_load_and_delete_old_version.pl - Does a complete update of MicrobeDB.

=head1 USAGE

download_load_and_delete_old_version.pl [-p <num_cpu>][-l <logger.conf>] [-h] -d directory ;

E.g.

#Do an update and store files in this directory using a single processor

download_load_and_delete_old_version.pl -d /share/genomes/

#Use all the power of my quad-core computer

download_load_and_delete_old_version.pl -p -d /share/genomes/

#Use only 2 of my 4 possible cores

download_load_and_delete_old_version.pl -p 2 -d /share/genomes/

=head1 OPTIONS
  
=over 4

=item B<-d, --directory <dir>>

The directory where MicrobeDB should place all flat files (Note: a date stamped sub-directory will be created for each update) (MANDATORY)

=item B<-p, --parallel [<# of proc>]>

Using this option without a value will use all CPUs on machine, while giving it a value will limit to that many CPUs. Without option only one CPU is used. 

=item B<-s, --special_download_options>

This allows options to be passed to the B<download_version.pl> script. Ensure that the options are enclosed in single quotes (e.g. -s '-s Pseudomonas -o').

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<download_load_and_delete_old_version.pl> This is the main script for installing/updating MicrobeDB

It acts as a wrapper to run 3 other scripts automatically (these can be run manually if you choose or if there are errors at a particular stage)

=over

=item 1. 

All genomes are downloaded from NCBI using Aspera (default) or FTP (download_version.pl)

=item 2.

Downloaded genomes are then extracted (unpack_version.pl)

=item 3.

All genomes are parsed and loaded into microbedb (load_version.pl)

=item 4.

Old versions in MicrobeDB are removed (note: custom version, saved versions, and most recent versions are never deleted)

=back

Note: This script can be set up in a cron job to run weekly/monthly/etc. Previous versions that are unsaved (see save_version.pl) are deleted except for the most recent (i.e. it will keep the most recent version in case their is problem with the update). Then all data is re-downloaded, re-unpacked, and re-loaded into the database.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

