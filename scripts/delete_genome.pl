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


#This script deletes a single genome from an existing version of MicrobeDB.
#gpv_id  or the directory of the genome must be specified. 

#*Note: delete_version.pl should be used for removing an entire directory of NCBI genomes or custom genomes.

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Log::Log4perl;
use Cwd qw(abs_path getcwd);

BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

#relative link to the api
use lib "../../";
use MicrobeDB::Search;

my ($dir,$logger_cfg,$help,$gpv_id);
my $res = GetOptions("directory=s" => \$dir,
		     "logger=s" => \$logger_cfg,
		     "gpv_id=i"=>\$gpv_id,
		     "help"=>\$help,
    ) or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify either -g gpv_id or -d dir.') unless (defined $dir || defined $gpv_id);

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;
 
my $so=new MicrobeDB::Search();
my $gpo;
if($gpv_id){
    #retrieve gpo by gpv_id search
    ($gpo)= $so->object_search(new MicrobeDB::GenomeProject(gpv_id=>$gpv_id));
    $logger->logdie("Can't find gpv_id: $gpv_id in MicrobeDB") unless $gpo;
    $logger->info("Removing genome,replicons, and genes associated with gpv_id: $gpv_id ");

}else{
    #retrieve gpo by directory search
    ($gpo)= $so->object_search(new MicrobeDB::GenomeProject(gpv_directory=>$dir));
    $logger->logdie("Can't find any genome with gpv_directory: $dir") unless $gpo;
    $logger->info("Removing genome,replicons, and genes associated with directory: $dir ");

}

#do the actual deletion
$gpo->delete();

	



__END__

=head1 Name

delete_genome.pl - Removes a single genome from MicrobeDB.

=head1 USAGE

delete_genome.pl [-l <logger.conf> -h] [-d <directory>|-g <gpv_id>]

E.g.

#Delete genome by gpv_id

delete_genome.pl -g 55555 

#Delete genome by directory

delete_genome.pl -d Pseudomonas_aeruginosa_LESB58

=head1 OPTIONS

=over 4

=item B<-g, --gpv_id <gpv_id>>

Remove the genome with this gpv_id from MicrobeDB.

=item B<-d, --directory <dir>>

Remove the genome in MicrobeDB associated with this directory. 

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<delete_genome.pl> This script deletes a single genome from an existing version of MicrobeDB. gpv_id  or the directory of the genome must be specified. 

*Note: delete_version.pl should be used for removing an entire directory of NCBI genomes or custom genomes.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

