package MicrobeDB::Version;

# Version contains search functionality for available versions of MicrobeDB
# along with routines to find replicon differences between versions.

use strict;
use warnings;

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use Carp;

my @version = qw(
    version_id
    dl_directory
    version_date
    used_by
    file_deleted
    prev_version_id
);

# put all the fields relavant to the database in a single array
my @_db_fields = (@version);

#store the db table names that are used in this object
my @_tables = qw(
version
);

my %_field_hash;
$_field_hash{version} = \@version;

my @FIELDS = (@version);

sub new {
    my ( $class, %arg ) = @_;

    #Bless an anonymous empty hash
    my $self = bless {}, $class;

    #Fill all of the keys with the fields
    foreach (@FIELDS) {
	$self->{$_} = undef;
    }

    #Set each attribute that is given as an argument
    foreach my $attr (keys(%arg) ) {
	$self->$attr($arg{$attr});
    }

    return $self;
}

# Return all the field names
sub field_names {
    my ($self) = @_;

    return @FIELDS;
}

sub table_names {
    my ($self) = @_;

    return @_tables;
}

1;
