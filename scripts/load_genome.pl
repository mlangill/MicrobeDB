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
use Pod::Usage;

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
    )or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify your a genome directory.') unless defined $dir;

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
$logger->logcroak("Can't figure out which version to load this genome into since directory: $version_dir is not in the version table") unless $version;

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

#if there was a parsing problem
$logger->logcroak("Couldn't add the following to microbedb: $dir ! Reason: $@") if $@;
    
__END__

=head1 Name

load_genome.pl - Loads a single genome into MicrobeDB

=head1 USAGE

load_genome.pl [-l <logger.conf>] [-h] -d directory 

E.g.

load_genome.pl -d /share/genomes/Bacteria_2011_01_01/Pseudomonas_aeruginosa_LESB58/

=head1 OPTIONS

=over 4

=item B<-d, --directory <dir>>

Specify a directory containing a single genome (one or more genbank files).

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<load_genome.pl> This script loads a single genome into the MicrobeDB database. This is useful when adding custom (non-RefSeq) genomes or when trying to debug why a particular genome is giving errors with the load script. 

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

	



