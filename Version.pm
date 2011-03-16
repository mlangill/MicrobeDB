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

package MicrobeDB::Version;

# Version contains search functionality for available versions of MicrobeDB
# along with routines to find replicon differences between versions.

use strict;
use warnings;

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");
use MicrobeDB::Search;
use Log::Log4perl qw(get_logger :nowarn);

use Carp;

my @FIELDS;
my @_tables;
my @version;
my @_db_fields;
my %_field_hash;
BEGIN{

@version = qw(
    version_id
    dl_directory
    version_date
    used_by
);

# put all the fields relavant to the database in a single array
@_db_fields = (@version);

#store the db table names that are used in this object
@_tables = qw(
version
);

$_field_hash{version} = \@version;

@FIELDS = (@version);

}
use fields @FIELDS;

my $logger = Log::Log4perl->get_logger();

sub new {
    my ( $class, %arg ) = @_;

    #bless and restrict the object
    my $self = fields::new($class);

    #Set each attribute that is given as an argument
    foreach my $attr (keys(%arg) ) {
	$self->$attr($arg{$attr});
    }

    return $self;
}

sub save_version {
	my ( $self, $name ) = @_;

	my $version_id=$self->version_id();
	return unless ($name);
	return unless ($version_id);

	my $so = new MicrobeDB::Search();
	my ($vo) = $so->table_search( 'version', { version_id => $version_id } );
	unless ( defined($vo) ) {
		return;
	}

	my $dbh = $self->_db_connect;

	my $sql;
	if ( $name eq 'null' ) {
		$sql = "UPDATE version SET used_by=null WHERE version_id = $version_id LIMIT 1";
	} else {

		#Check if someone else is already using this version
		if ( defined( $vo->{'used_by'} ) ) {
			$name = join( ', ', $vo->{'used_by'}, $name );
		}

		$sql = "UPDATE version SET used_by='$name' WHERE version_id = $version_id LIMIT 1";
	}

	#
	my $sth = $dbh->prepare($sql);

	#call the statement
	return $sth->execute();

}


#Looks through the version table for any versions that are not being used
#Therefore, used_by field must be set; otherwise all data is deleted
sub delete_unused_versions {
    my ($self) = @_;
    my $so     = new MicrobeDB::Search();
    my @vo     = $so->object_search(new MicrobeDB::Version());
    
    #make a lookup for dl_directories in case several versions use the same directory
    my %dl_dir;
    foreach(@vo){
	$dl_dir{$_->dl_directory()}++;
    }

    #order by version id so that we can keep the most recent version
    my @sort_versions = sort { $a->version_id() <=> $b->version_id() } @vo;
    
    my $custom_version=0;
    if($sort_versions[0]->version_id()==0){
	$custom_version=1;
	shift(@sort_versions);
    }

    my $version_num=scalar(@sort_versions);
    if($custom_version){
	$logger->info("MicrobeDB contains a custom version as well as $version_num other version(s). Scanning these non-custom versions for deletion.");
    }else{
	$logger->info("MicrobeDB contains $version_num version(s). Scanning these versions for deletion.");
    }
    my $delete_flag=0;

    if($version_num >2){
	#remove the latest 2 versions (highest at end of array) from the versions that may be deleted
	#i.e. keep the 2 most recent versions
	my $ver1 = pop(@sort_versions);
	my $ver2 = pop(@sort_versions);
	$logger->info("Keeping the two most recent versions; ".$ver1->version_id()." and ".$ver2->version_id());
	
	foreach my $curr_vo (@sort_versions) {
	    if($curr_vo->{version_id} == 0){
		$logger->info("Not deleting version ". $curr_vo->version_id() .", this is the custom genomes version.");
		next;
	    }elsif(defined($curr_vo->used_by())){
		$logger->info("Not deleting version ". $curr_vo->version_id() .", being used by ".$curr_vo->used_by() );
	    }else{
		$delete_flag=1;
		if($dl_dir{$curr_vo->dl_directory()} >1 ){
		    $dl_dir{$curr_vo->dl_directory()}--;
		    $logger->info("Deleting mysql associated with version ".$curr_vo->version_id()." (files are NOT being deleted since they are shared with another version)");
		    $curr_vo->delete_version(1);
		    
		}else{
		    $logger->info("Deleting mysql and files associated with version ".$curr_vo->version_id());
		    $curr_vo->delete_version();
		}
	    }
	}
    }
    $logger->info("No MicrobeDB versions need to be deleted.") unless $delete_flag;
}


#Deletes a complete microbedb version (from all tables) AND removes flat files unless save_files is set to 1
sub delete_version {
	my ( $self, $save_files ) = @_;
	my $version_id=$self->version_id();
	my $dbh = $self->_db_connect;

	#check the version table to make sure no one is using the data
	my $so = new MicrobeDB::Search();
	my ($vo) = $so->object_search( new MicrobeDB::Version(version_id => $version_id) );
	croak "Version id: $version_id was not found in version table!" unless defined($vo);
	my $being_used   = $vo->used_by();
	my $dl_directory = $vo->dl_directory();
	if ($being_used) {
		warn "Version $version_id is being used by $being_used. This version will NOT be deleted!";
		return;
	}

	#list of tables to delete records from
	my @tables_to_delete = qw/genomeproject replicon gene version/;

	#delete records corresponding to the version id in each table (use QUICK since there are millions of genes)
	foreach my $curr_table (@tables_to_delete) {
	    $logger->info("Deleting version: $version_id from $curr_table table");
		my $sql = "DELETE QUICK FROM $curr_table WHERE version_id = $version_id ";

		#Prepare the statement
		my $sth = $dbh->prepare($sql);

		#call the statement
		$sth->execute();

	}
	$logger->info("Optimizing all microbedb tables");
	#optimize the tables (needed to reduce "overhead" in the tables after large deletes, especially when using DELETE QUICK)
	$dbh->do("OPTIMIZE NO_WRITE_TO_BINLOG TABLE ".join(",",@tables_to_delete));

	unless ($save_files) {
	    $logger->info("Deleting directory: $dl_directory");
		#delete the actual files
		`rm -rf $dl_directory`;
	}

}


# Return all the field names
sub field_names {
    my ($self) = @_;

    return @FIELDS;
}

sub table_names {
    my ($self) = @_;
    
    return $_tables[0];
}

1;
