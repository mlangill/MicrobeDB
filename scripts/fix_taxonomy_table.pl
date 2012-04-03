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

#Author Morgan Langille
#Last updated: see github

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl;
use Pod::Usage;

#relative link to the api
use lib "../../";
use MicrobeDB::Search;
use MicrobeDB::Parse;

my $help;
my $res = GetOptions("help"=>\$help)or pod2usage(2);

pod2usage(-verbose=>2) if $help;

# Set the logger config to a default if none is given
my $logger_cfg = "logger.conf";
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;


#retrieve all genome projects
my $so= new MicrobeDB::Search();
my @gpos=$so->object_search(new MicrobeDB::GenomeProject());

foreach my $gpo(@gpos){
    my $taxon_id=$gpo->taxon_id();
    next unless defined($taxon_id);

    next if defined($gpo->superkingdom());

    $logger->info("No taxonomy information exists for taxon_id: $taxon_id. Going to reload this genome.");
    
    my $dir = $gpo->gpv_directory();
    system("./reload_genome.pl -d $dir");

}
	

__END__

=head1 Name

fix_taxonomy_table.pl - Reloads a single genome into MicrobeDB

=head1 USAGE

fix_taxonomy_table.pl [-h]

E.g.

fix_taxonomy_table.pl

=head1 OPTIONS

=over 4

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<fix_taxonomy_table.pl> This script examines the taxonomy table and tries to retrieve information from NCBI for taxon ids that were not previously retrieved when loading the version.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut




