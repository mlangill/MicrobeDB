# Copyright (C) Matthew R. Laird
# Author lairdm@sfu.ca

# This file is part of MicrobeDB

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

package MicrobeDB::Iterator;

# This class contains an iterator object for use with 
# MicrobeDB::Search.  Some search results are too large
# to return as a single object so the iterator class
# gives access to the results row-by-row.

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use strict;
use warnings;
use Carp;

my @FIELDS;

BEGIN {
@FIELDS = qw(
  ret_obj
  dbh_obj
);
}
use fields @FIELDS;

sub new {
    my ($class, %arg) = @_;

    # bless and restruct the object
    my $self = fields::new($class);
    
    foreach my $attr ( keys(%arg) ) {

	#set the attribute in the object
	$self->$attr( $arg{$attr} );
    }

    return $self;
}

# Return the next object from the database

sub nextRecord {
    my ($self) = @_;

    	#Extract the results back into objects
	{

	    #temporarily turn off strict
	    no strict "refs";
	    if ( my $curr_row = $self->{dbh_obj}->fetchrow_hashref ) {

		#Create a object of the return type from the hash
		my $obj = $self->{ret_obj}->new(%$curr_row);
		return $obj;
	    }
	}

	return undef;
}

sub rows {
    my ($self) = @_;

    return $self->{dbh_obj}->rows;
}
