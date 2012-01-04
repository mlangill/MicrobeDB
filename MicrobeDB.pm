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

package MicrobeDB::MicrobeDB;

#MicrobeDB is the parent class for all classes in the microDB project
#perldoc MicrobeDB - for more information (or see end of this file)

use strict;
use warnings;
use Carp;
use DBI;

our $AUTOLOAD;

my @FIELDS;
BEGIN{
    @FIELDS = qw(comment);
}
use fields @FIELDS;

#PATH Settings

#MicrobeDB MySQL settings
my $db_config = "$ENV{HOME}/.my.cnf";
die "MySQL config file:$db_config can not be found!" unless -e $db_config;
my $database=$ENV{"MicrobeDB"}||"microbedb";
my $dsn = "DBI:mysql:database=$database;mysql_read_default_file=$db_config";

#note that these fields are taken from the config file "my.cnf"
my ($user,$pass) = ("","");


sub new {
	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

	#Set each attribute that is given as an arguement
	foreach ( keys(%arg) ) {
		$self->$_( $arg{$_} );
	}
	
	return $self;
}

#inserts a record in the database
#Input: name of table and hash ref
#Requires the table name, an array ref of fields and an array ref of values
#Returns the primary key for the record that was created
sub _insert_record {
    my ( $self, $object, $table_name ) = @_;

    my $dbh = $self->_db_connect();

    my @fields = $object->field_names($table_name);

    my @values;
    foreach (@fields) {
        push( @values, $object->$_ );
    }

#Need to add back ticks around each field name because certain fields (eg. order) will cause problems
    my @new_fields;
    foreach (@fields) {
        push( @new_fields, "`$_`" );
    }

    #Make the array of fields into a comma seperated string
    my $fields = join( ',', @new_fields );

 #Makes a string of ?'s so we can bind to them later
 #Note: always bind the values because it looks after converting undef to null
    my $bind = join( ',', ('?') x @values );

    #my $sql = "INSERT IGNORE $table_name ($fields) VALUES ($bind)";

#Use REPLACE instead of INSERT so this method can be used for both inserts or replacements
    my $sql = "REPLACE $table_name ($fields) VALUES ($bind)";

    #Create new genomeproject recordicrobedb
    my $sth = $dbh->prepare($sql);

    #call the statement
    $sth->execute(@values);

    #This should return the auto_increment number that was just updated
    return $dbh->last_insert_id( undef, undef, undef, undef );

}

sub _db_connect {
	my ($self) = @_;

	#Make connection to the database
	
	# Do we have an existing connection? If so, just return it
	# Yay singletons!
#	return $self->{dbhandle} if($self->{dbhandle});

	my $dbh;
	
	my $max_tries = 5;
	for my $try (1..$max_tries) {
		eval {
			#Try to connect to microbeDB
			$dbh = DBI->connect( $dsn, $user, $pass, { RaiseError => 1 } )
			  || die $DBI::errstr;
		};
		#if there is an error or we the handle is empty then try again
		if($@ || !defined($dbh)){
	
		croak("Failed to connect to microbeDB! $max_tries tries have failed! \n$@") if $try == $max_tries;
		warn "Failed to connect to microbeDB! Trying again in 5 seconds. This is attempt $try of $max_tries. \n$@";
		
		#increase wait time by 5 seconds on each failure
		sleep(5*$try);
		}else{
		    last;
		}
	}
	unless(defined($dbh)){
	    die "Can't connect to db:$!";
	}
	
	# Save the dhb for later
#	$self->{dbhandle} = $dbh;

	return $dbh;
}

# This takes the place of methods to set or get the value of an attribute
sub AUTOLOAD {
    my ($self,$newvalue) = @_;
    #get the unknown method call
    my $attr = $AUTOLOAD;

    #Keep only the method name
    $attr =~ s/.*:://;    

    #Die if the key does not already exist in the hash
    unless (exists($self->{$attr})){
#	croak "No such attribute '$attr' exists in the class ";
    }

    # Turn off strict references to enable "magic" AUTOLOAD speedup
    no strict 'refs';

    # define subroutine
    *{$AUTOLOAD} = sub {my($self,$newvalue)=@_;
			$self->{$attr}=$newvalue if defined($newvalue);
			return $self->{$attr}};    

    # Turn strict references back on
    use strict 'refs';

    #Set the new value for the attribute if available
    $self->{$attr} = $newvalue if defined($newvalue);

    #Always return the current value for the attribute
    return $self->{$attr};
}



#returns an array of all field names for this class
sub all_fields{
  my ($self) = @_;
  return keys(%$self);
}

#set all the fields in the object when given a hash
sub set_hash{
	my($self,%hash)=@_;
	foreach(keys(%hash)){
		$self->$_($hash{$_});
	}
}

#returns a hash of the complete object
sub get_hash{
	my ($self) = @_;
	return %{$self};
}

#print object to tab-delimited file
#TODO: need to update the print function to use filenames
sub print_obj{
	my ($self, $filename) =@_;
	my @print_line = join('\t',values(%$self));
	print @print_line;
}

#Anything put in this method will be run when the object is destroyed
sub DESTROY{
}


1;

__END__

=head1 NAME

Replicon: contains features that are associated with a single replicon (chromosome or plasmid) within an organism

=head1 Synopsis

=head1 AUTHOR

Morgan Langille

=head1 Date Created

June 2nd, 2006

=cut


