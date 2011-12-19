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
use lib "../../../";
use MicrobeDB::Search;

my $help;
GetOptions("help"=>\$help)or pod2usage(2);

pod2usage(-verbose=>2) if $help;

# Set the logger config to a default if none is given
my $logger_cfg = "../../scripts/logger.conf";
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

#get current database schema version
my $so=new MicrobeDB::Search();
my ($result)=$so->table_search('microbedb_meta',{meta_key=>'schema_version'});

my $schema_version=$result->{meta_value};

if(defined($schema_version)){
    $logger->info("You are currently using MicrobeDB schema version: $schema_version\n");
}else{
    $logger->logdie("Can't find schema version in your MicrobeDB");
}

my @update_files = glob('schema_updates/*.sql');

#Get a list of all updates
my %schema_updates;
foreach my $update(@update_files){
    if($update =~/update_schema_v(\d+)\.sql/){
	$schema_updates{$1}=$update;
    }else{
	$logger->warn("Can't parse schema version information from file: $update");
    }
}

my $new_version_flag=0;
foreach my $ver_number(sort keys %schema_updates){
    if($ver_number > $schema_version){
	$new_version_flag=1;
	my $update_file=$schema_updates{$ver_number};
	$logger->info("Your schema is out-of-date, updating to version: $ver_number with mysql update file: $update_file");
   
	my $update_cmd = 'mysql microbedb < '.$update_file;
	system($update_cmd);

        #update the schema_version number in the database
	my $dbh = MicrobeDB::MicrobeDB->_db_connect();
	my $sql = "UPDATE microbedb_meta SET meta_value=$ver_number WHERE meta_key='schema_version'";
	$dbh->do($sql);

    }
}

$logger->info("Your schema is up-to-date.") unless $new_version_flag;

__END__

=head1 Name

update_database_schema.pl - Updates the MicrobeDB database schema

=head1 USAGE

update_database_schema.pl [-h]

E.g.

update_database_schema.pl

=head1 OPTIONS

=over 4

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<update_database_schema.pl> This script checks to see if any updates to the local MySQL schema needs to be updated and if so makes the changes. This script should be run the MicrobeDB software is updated either manually (by downloading the entire package) or using git (git pull). 

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

