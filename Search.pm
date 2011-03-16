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

package MicrobeDB::Search;

#Search allows searching of the MicrobeDB
#perldoc Search - for more information (or see end of this file)

use strict;
use warnings;

use Carp;
use DBI;

#inherit common methods and fields from the MicrobeDB class
use base ("MicrobeDB::MicrobeDB");

require MicrobeDB::Replicon;
require MicrobeDB::GenomeProject;
require MicrobeDB::Gene;
require MicrobeDB::Version;

my @FIELDS;
BEGIN{

#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

my @_search = qw(
  return_obj
  return_seqs
  advanced_where
);

my @_db_connect = qw(
  dbh
);

@FIELDS = ( @_search, @_db_connect );

}
use fields @FIELDS;

sub new {
	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

	#Default is not to retrieve the sequence
	$self->return_seqs(0);

	#Advanced search is turned off by default
	$self->advanced_where(0);

	#Set each attribute that is given as an arguement
	foreach ( keys(%arg) ) {
		$self->$_( $arg{$_} );
	}

	return $self;
}

sub table_search {
	my ( $self, $table_name, $search_hash ) = @_;

	my $sql = "SELECT * FROM $table_name";

	#Set the fields and values that we will search on
	my ( @fields, @values );
	foreach ( keys(%$search_hash) ) {
		push( @fields, $_ );
		push( @values, $search_hash->{$_} );
	}

	if ( scalar(@fields) > 0 ) {

		#Add where statements
		$sql .= " WHERE ";
	

	my @wheres;

  #for the advanced where we use seperate the operator from the value string by splitting on a space
	if ( $self->advanced_where ) {
		for ( my $i = 0 ; $i < scalar(@fields) ; $i++ ) {
			my @tmp_ary  = split( / /, $values[$i] );
			my $operator = shift(@tmp_ary);
			my $value    = join( "", @tmp_ary );
			my $tmp      = $fields[$i] . " $operator " . "\"$value\"";
			push( @wheres, $tmp );
		}

		#just use "=" when advanced where is not needed
	} else {
		for ( my $i = 0 ; $i < scalar(@fields) ; $i++ ) {
			my $tmp .= $fields[$i] . " = " . "\"$values[$i]\"";
			push( @wheres, $tmp );
		}
	}

	$sql .= join( ' AND ', @wheres );
	}
	#Do the actual mysql query
	my $dbh = $self->_db_connect();
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	#put each record found into an array
	my @return_objs;
	while ( my $curr_row = $sth->fetchrow_hashref ) {

		#Create a object of the return type from the hash
		push( @return_objs, $curr_row );
	}

	$dbh->disconnect();
	return @return_objs;
}

#called by the user to do a search using an object as the search fields
sub object_search {
	my ( $self, $search_obj ) = @_;
    
    croak "A search object must be defined when using object_search()!\n" unless defined($search_obj);
	
	my $obj_type = ref($search_obj);

	#If the return object is not set use the search object by default
	my $ret_obj;
	if ( defined( $self->return_obj ) ) {
		$ret_obj = $self->return_obj;
	} else {
		$ret_obj = ( ref($search_obj) );
	}

	#Get tables in return object
	my @table_names = $ret_obj->table_names;

	#Any elements that have been set to search on are pushed onto @fields and @values
	my ( @fields, @values );
	foreach ( $search_obj->field_names('db') ) {
		if ( defined( $search_obj->{$_} ) ) {
			push( @fields, $_ );
			push( @values, $search_obj->{$_} );
		}
	}

	#Form the first part of the select statement (ie. Select tablename1.* tablename2.* FROM)
	my $sql = $self->_create_select(@table_names);

	#Always use the first table_name as the table to join everything else to
	$sql .= " FROM $table_names[0]";

	#make a hash to keep track of tables that have already been joined
	my %joined;
	$joined{ $table_names[0] } = 1;

	push( @table_names, $search_obj->table_names );

	#Get rid of tables that are in objects more than once
	my %temp;
	@temp{@table_names} = ();
	@table_names = keys %temp;

	#Join all the tables (skip the first one since we already joined it)
	foreach my $need_joined (@table_names) {
		if ( $joined{$need_joined} ) { next; }

		#go through all the previous joined tables until we find one that we can use a joiner with
		foreach my $already_joined ( keys(%joined) ) {

			#see if there is a field that can be used to join the two tables on
			my $joiner = $self->_get_joiner( $already_joined, $need_joined );
			if ( defined($joiner) ) {

				#add the join statement to the sql statememt;
				my $join_str =
				  " LEFT JOIN $need_joined ON ($need_joined.$joiner = $already_joined.$joiner) ";
				$sql .= $join_str;
				$joined{$need_joined} = 1;

				#don't need to look for any other ways to join the table
				last;
			}
		}

	}

	#Add where statements
	$sql = $self->_create_where( $sql, $search_obj, \@fields, \@values );

	#Debug
	#print "\n $sql \n";

	#Do the actual mysql query
	my $dbh = $self->_db_connect();
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my @return_objs;

	#Extract the results back into objects
	{

		#temporarily turn off strict
		no strict "refs";
		while ( my $curr_row = $sth->fetchrow_hashref ) {

			#Create a object of the return type from the hash
			push( @return_objs, $ret_obj->new(%$curr_row) );
		}
	}
	$dbh->disconnect();
	return @return_objs;
}

sub _create_where {
	my ( $self, $sql, $obj, $field_ref, $value_ref ) = @_;
	my @fields = @$field_ref;
	my @values = @$value_ref;

	if ( scalar(@fields) > 0 ) {

		#Add where statements
		$sql .= " WHERE ";
	}

	my @wheres;

	if ( $self->advanced_where ) {
		for ( my $i = 0 ; $i < scalar(@fields) ; $i++ ) {
			my $tmp      = $obj->table_names( $fields[$i] );
			my @tmp_ary  = split( / /, $values[$i] );
			my $operator = shift(@tmp_ary);
			my $value    = join( "", @tmp_ary );
			$tmp .= "." . $fields[$i] . " $operator " . "\"$value\"";
			push( @wheres, $tmp );
		}

	} else {
		for ( my $i = 0 ; $i < scalar(@fields) ; $i++ ) {
			my $tmp = $obj->table_names( $fields[$i] );
			$tmp .= "." . $fields[$i] . " = " . "\"$values[$i]\"";
			push( @wheres, $tmp );
		}
	}

	$sql .= join( ' AND ', @wheres );

	return $sql;
}

#Form the first part of the select statement (ie. Select tablename1.* tablename2.* FROM)
sub _create_select {
	my ( $self, @table_names ) = @_;

	my $sql = "SELECT DISTINCT ";

	#Use all fields if the user specifies that they want sequences
	if ( $self->return_seqs ) {
		my @select_start;
		foreach (@table_names) {
			push( @select_start, "$_.*" );
		}
		$sql .= join( ',', @select_start );
	} else {
		my @select_start;
		foreach (@table_names) {

			#select all fields but the sequence field if we are in the replicon table
			if ( $_ eq 'replicon' ) {
				my $tmp_rep_obj = new MicrobeDB::Replicon();
				my @rep_fields  = $tmp_rep_obj->field_names('replicon');
				foreach (@rep_fields) {
					unless ( $_ eq 'rep_seq' ) {
						push( @select_start, "replicon.$_" );
					}
				}
			} else {
				push( @select_start, "$_.*" );
			}
		}
		$sql .= join( ',', @select_start );
	}
}

#Tells what column to link two tables on
sub _get_joiner {
	my ( $self, $table1, $table2 ) = @_;
	my %joiner_lookup;
	$joiner_lookup{genomeproject}{version}  = 'version_id';
	$joiner_lookup{genomeproject}{taxonomy} = 'taxon_id';
	$joiner_lookup{genomeproject}{replicon} = 'gpv_id';
	$joiner_lookup{genomeproject}{gene}     = 'gpv_id';
	$joiner_lookup{replicon}{version}       = 'version_id';
	$joiner_lookup{replicon}{gene}          = 'rpv_id';
	$joiner_lookup{replicon}{genomeproject} = 'gpv_id';
	$joiner_lookup{gene}{genomeproject}     = 'gpv_id';
	$joiner_lookup{gene}{replicon}          = 'rpv_id';
	$joiner_lookup{gene}{version}           = 'version_id';
	return $joiner_lookup{$table1}{$table2};

}


# When an object is no longer being used, this will be automatically called
sub DESTROY {

}
1;

__END__

=head1 NAME

Search: allows searching of the MicrobeDB 

=head1 Synopsis
use MicrobeDB::Search;

=head1 AUTHOR

Morgan Langille

=head1 Date Created

June 5th, 2006

=cut







