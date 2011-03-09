package MicrobeDB::Gene;

#Gene contains features that are associated with a single gene.
#perldoc Gene - for more information (or see end of this file)

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use strict;
use warnings;
use Carp;

my @FIELDS;
my @gene;
my @_db_fields;
my @_tables;
my %_field_hash;
BEGIN {

#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

my @gene = qw(
  gene_id
  rpv_id
  version_id
  gpv_id
  gid
  pid
  protein_accnum
  gene_type
  gene_start
  gene_end
  gene_length
  gene_strand
  gene_name
  locus_tag
  gene_product
  gene_seq
  protein_seq
);


my @version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
my @_db_fields = (@gene, @version);
my %temp;
@temp{@_db_fields} =();
@_db_fields = keys %temp; 

#store the db tablenames that are used in this object
my @_tables = qw(
gene
version
);
my %_field_hash;
$_field_hash{gene} = \@gene;
$_field_hash{version}  = \@version;

@FIELDS = ( @_db_fields );

}

use fields @FIELDS;


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

#returns an array of fields
#all fields are returned if a table name is not given
sub field_names{
	my ($self, $table_name)=@_;
	unless(defined($table_name)){
		return @FIELDS
	}
	if($table_name eq 'gene'){ return @gene}

	#special case
	if($table_name eq 'db'){return @_db_fields}
	return;
}

sub table_names {    
	my ( $self, $field_name ) = @_;

	#return all table names if no field name is given
	unless ( defined($field_name) ) {
		return @_tables;
	}
	my $table_name;

	#look up what table the field name is in
	foreach my $curr_table ( keys(%_field_hash) ) {
		#stop looking if we already found it
		unless ( defined($table_name) ) {
			#look at each field name in the current table
			foreach ( @{ $_field_hash{$curr_table} } ) {
				if ( $field_name eq $_ ) {
					#set the found table name
					$table_name = $curr_table;
					#exit the inner loop
					last;
				}
			}
		}
	}
	return $table_name;
}

1;

__END__

=head1 NAME

Gene: contains features that are associated with a single gene.

=head1 Synopsis

=head1 AUTHOR

Morgan Langille

=head1 Date Created

June 5th, 2006

=cut



