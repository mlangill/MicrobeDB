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
use MicrobeDB::FullUpdate;

my ($help,$version_id);
my $res = GetOptions(    "version=i"=> \$version_id,
"help"=>\$help)or pod2usage(2);

pod2usage(-verbose=>2) if $help;

# Set the logger config to a default if none is given
my $logger_cfg = "logger.conf";
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;


#retrieve all genome projects
my $so= new MicrobeDB::Search();
my @gpos=$so->object_search(new MicrobeDB::GenomeProject(version_id=>$version_id));

foreach my $gpo(@gpos){
    my $taxon_id=$gpo->taxon_id();
    next unless defined($taxon_id);

    next if defined($gpo->superkingdom());

    $logger->info("No taxonomy information exists for taxon_id: $taxon_id. Retrieving it now.");

    my $parse_obj=MicrobeDB::Parse->new('gpo'=>$gpo);

    #get the taxonomy from NCBI
    $parse_obj->parse_taxonomy();

    unless(defined($gpo->superkingdom())) {
	$logger->info("Still couldn't retrieve information for taxon_id: $taxon_id.");
	next;
    }
    
    #create an update object
    my $update_obj = MicrobeDB::FullUpdate->new('version_id'=>$gpo->version_id());

    #insert the taxonomy information to the taxonomy table (should replace if taxon_id already exists)
    my $tax_id = $update_obj->_insert_record( $gpo, 'taxonomy' );
    
}
	

__END__

=head1 Name

fix_taxonomy_table.pl - Retrieves missing taxonomy information.

=head1 USAGE

fix_taxonomy_table.pl [-h -v <version_id>]

E.g.

#Find missing taxonomy information for genomes in all versions

fix_taxonomy_table.pl

#Find missing taxonomy information for genomes in a specific version

fix_taxonomy_table.pl -v 23


=head1 OPTIONS

=over 4

=item B<-v, --version_id>

Only get fill missing taxonomy information for genomes associated with given version id. 

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<fix_taxonomy_table.pl> This script examines the taxonomy table and tries to retrieve information from NCBI for taxon ids that were not previously retrieved when loading the version.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut




