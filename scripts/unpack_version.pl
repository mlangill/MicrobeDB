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

#Unpacks (tar/gzip) genome files from ftp download
#This is usually run after download_version.pl (by the download_load_and_delete_old_version.pl)

use strict;
use warnings;
use Parallel::ForkManager;
use Getopt::Long;
use Pod::Usage;
use Log::Log4perl;
  
my ($download_dir,$logger_cfg,$help,$parallel);
my $res = GetOptions("directory=s" => \$download_dir,
		     "parallel:i"=>\$parallel,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    )or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify your download directory.') unless defined $download_dir;

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
	$cpu_count= Sys::CPU::cpu_count();
    }else{
	$cpu_count=$parallel;
    }
}


chdir($download_dir);
my @compressed_files = glob($download_dir .'all.*.tar.gz');

$logger->logdie("Didn't find any files to uncompress. Are you sure your directory: \"$download_dir\" contains compressed files?") unless @compressed_files;


$logger->info("Parallel proccessing the unpacking step with $cpu_count proccesses.") if defined($parallel);
my $pm = new Parallel::ForkManager($cpu_count);

for my $tarball (@compressed_files){
    my $pid = $pm->start and next; 
    $logger->info("Unpacking $tarball");
    system("tar xzf $tarball");
   
    $logger->logdie("Unpacking of $tarball failed!") if $?;
    
    $logger->info("Done unpacking and now deleting $tarball");
    unlink($tarball);
    
     $pm->finish;
}
$pm->wait_all_children;
$logger->info("All done unpacking.");

__END__

=head1 Name

unpack_version.pl - Uncompresses all RefSeq bacteria and archaea genomes previously downloaded from NCBI.

=head1 USAGE

unpack_version.pl [-p <num_cpu>][-l <logger.conf>] [-h] -d directory ;

E.g.

#Uncompress all compressed files in this directory using a single processor

unpack_version.pl -d /share/genomes/Bacteria_2011_01_01/

#Use all the power of my quad-core computer

unpack_version.pl -p -d /share/genomes/Bacteria_2011_01_01/

#Use only 2 of my 4 possible cores

unpack_version.pl -p 2 -d /share/genomes/Bacteria_2011_01_01/

=head1 OPTIONS

=over 4

=item B<-d, --directory <dir>>

The download directory containing compressed genome files downloaded from NCBI via download_version.pl.

=item B<-p, --parallel [<# of proc>]>

Using this option without a value will use all CPUs on machine, while giving it a value will limit to that many CPUs. Without option only one CPU is used. 

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<unpack_version.pl> This script uncompresses gzipped tarballs that were downloaded from NCBI's FTP website. This step can be sped up by using the --parallel flag. 

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

