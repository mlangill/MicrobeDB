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
use Pod::Usage;

use Cwd qw(abs_path getcwd);
use Parallel::ForkManager;
use Sys::CPU;

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
 
use XML::Simple;
use LWP::Simple;

my ($download_dir,$logger_cfg,$custom,$help,$parallel);
my $res = GetOptions("directory=s" => \$download_dir,
		     "parallel:i"=>\$parallel,
		     "logger=s" => \$logger_cfg,
		     "custom"=>\$custom,
		     "help"=>\$help,
    )or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify a directory.') unless defined $download_dir && -d $download_dir;

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;

my $cpu_count=0;

#if the option is set
if(defined($parallel)){
    #option is set but with no value then use the max number of proccessors
    if($parallel ==0){
	#load this module dynamically
	eval("use Sys::CPU;");
	$cpu_count=Sys::CPU::cpu_count();
    }else{
	$cpu_count=$parallel;
    }
}

$logger->info("Parallel proccessing the loading step with $cpu_count proccesses.") if defined($parallel);
my $pm = new Parallel::ForkManager($cpu_count);

#Load the genome into microbedb
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
	    my $pid = $pm->start and next; 
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
		$logger->error("Couldn't add the following to microbedb: $curr_dir ! Reason: $@");
	      
	    }
	    $pm->finish;
	    
	}
	$pm->wait_all_children;
	return $up_obj->version_id();

}



sub get_sub_dir {
    my $head_dir = shift;

    $head_dir .= '/' unless ( $head_dir =~ /\/$/ );

    opendir my($dh), $head_dir || die "Error opening $head_dir: $!";

    my @dirs = grep { ! /^\.\.?$/ } grep { -d $_ } map { "$head_dir$_/" } readdir $dh;

    closedir $dh;

    return remove_dir(@dirs);
}

#removes any directories that does not contain a genome project (or causes other problems)
sub remove_dir {
	my @genome_dir = @_;
	my @temp;

	#Filter out some directories we don't want
	foreach (@genome_dir) {
		next if ( $_ =~ /CLUSTERS/ );
		next if $_ =~ /\.\/$/;
		next if $_ =~ /\.\.\/$/;
		next if $_ =~ /log$/;

		push( @temp, $_ );
	}
	return @temp;
}


__END__

=head1 Name

load_version.pl - Loads a version of genomes into MicrobeDB

=head1 USAGE

load_version.pl [-c -p [<# proc>] -l <log conf> -h] -d directory 

E.g.

load_version.pl -d /share/genomes/Bacteria_2011_01_01/

=head1 OPTIONS

=over 4

=item B<-d, --directory <dir>>

Mandatory. A directory containing directories of genomes to be loaded into MicrobeDB. 

=item B<-c, --custom>

Signifies that this directory contains non-downloaded NCBI genomes. Genomes are assigned version_id 0.

=item B<-p, --parallel [<# of proc>]>

Using this option without a value will use all CPUs on machine, while giving it a value will limit to that many CPUs. Without option only one CPU is used. 

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<load_version.pl> This script loads all genomes from a recent download into the MicrobeDB database. 
The given directory should contain several sub-directories with each containing a genome (one or more genbank files). 
This script is normally run after "unpack_version.pl".
This script can also be used to add non-RefSeq (personal unpublished) genomes. It is recommended to use the --custom option when loading non-RefSeq genomes so that they are stored somewhat seperate from other versions and always with version_id=0. 

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

