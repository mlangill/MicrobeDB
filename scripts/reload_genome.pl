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
use Pod::Usage;

my $path;
BEGIN{
# Find absolute path of script
($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

my ($dir,$help);
my $res = GetOptions("directory=s" => \$dir,
		     "help"=>\$help,
    )or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify a genome directory.') unless defined $dir;

my $delete_cmd=$path.'/delete_genome.pl -d '.$dir;
#delete old one
system($delete_cmd);

#add new one
system($path.'/load_genome.pl -d '.$dir);

__END__

=head1 Name

reload_genome.pl - Reloads a single genome into MicrobeDB

=head1 USAGE

reload_genome.pl [-h] -d directory ;

E.g.

reload_genome.pl -d /share/genomes/Bacteria_2011_01_01/Pseudomonas_aeruginosa_LESB58/

=head1 OPTIONS

=over 4

=item B<-d, --directory <dir>>

Specify a directory containing a single genome (one or more genbank files).

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<reload_genome.pl> This removes a genome from MicrobeDB (using delete_genome.pl) and the loads it back into MicrobeDB (using load_genome.pl).
Convenient when you have a genome that is giving erros while loading.


=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut


	



