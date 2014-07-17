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

package MicrobeDB::Gene;

#Gene contains features that are associated with a single gene.
#perldoc Gene - for more information (or see end of this file)

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use strict;
use warnings;
use Carp;

use Bio::SeqIO; 
use Bio::Perl;

my @FIELDS;
my @gene;
my @_db_fields;
my @_tables;
my %_field_hash;
my @version;
BEGIN {

#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

@gene = qw(
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
);


@version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
@_db_fields = (@gene, @version);
my %temp;
@temp{@_db_fields} =();
@_db_fields = keys %temp; 

#store the db tablenames that are used in this object
@_tables = qw(
gene
version
);

$_field_hash{gene} = \@gene;
$_field_hash{version}  = \@version;

my @_other = qw(
  replicon
  genomeproject
  seqobj
  gene_seq
  protein_seq
);

@FIELDS = ( @_db_fields, @_other );

}

use fields @FIELDS;


sub new {
	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

	#Set each attribute that is given as an arguement
	foreach ( keys(%arg) ) {
	    # Skip the type of gene_seq & protein_seq, we never store these
	    next if($_ eq 'gene_seq');
	    next if($_ eq 'protein_seq');

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

#returns the genomeproject associated with this gene
sub genomeproject{
    my ($self, $new_genomeproject) =@_;

    $self->{genomeproject} = $new_genomeproject if defined($new_genomeproject);

    if(defined($self->{genomeproject})) {
	return $self->{genomeproject};
    } else {
	my $so = new MicrobeDB::Search();
	my ($genomeproject) = $so->object_search( new MicrobeDB::GenomeProject(gpv_id => $self->gpv_id()));
	$self->{genomeproject} = $genomeproject;
	return $genomeproject;
    }
}

#returns the replicon associated with this gene
sub replicon{
    my ($self, $new_replicon) =@_;

    $self->{replicon} = $new_replicon if defined($new_replicon);

    if(defined($self->{replicon})) {
	return $self->{replicon};
    } else {
	my $so = new MicrobeDB::Search();
	my ($replicon) = $so->object_search( new MicrobeDB::Replicon(rpv_id => $self->rpv_id()));
	$self->{replicon} = $replicon;
	return $replicon;
    }
}

# Override to pull the sequences from the flat
# files ratherthan the database

sub gene_seq() {
    my ($self) = @_;

    if(! defined($self->{seqobj})) {
	my $replicon = $self->replicon();

	my $filename = $replicon->get_filename('fna');

	if(!defined($filename)) {
	    $filename = $replicon->get_filename('gbk');
	}

	if(!defined($filename)) {
	    croak "Error, fna or gbk file needed for retrieving sequences";
	}

	# Grab the fna file via bioperl
	my $in = new Bio::SeqIO(-file => $filename);

	my $seqobj = $in->next_seq();

	return (($self->gene_strand() eq '-1' || $self->gene_strand() eq '-') ?
		reverse_complement_as_string($seqobj->subseq($self->gene_start(), $self->gene_end())) :
		$seqobj->subseq($self->gene_start(), $self->gene_end()));

	# Holding all the seqobj in memory was taking to much memory
	# and crashing the scripts...
        # Iterates through each genomic dna sequence in the file,
	# returns a BioSeq object representing it
#	$self->{seqobj} = $in->next_seq();

    } else {

	return (($self->gene_strand() eq '-1' || $self->gene_strand() eq '-') ?
		reverse_complement_as_string($self->{seqobj}->subseq($self->gene_start(), $self->gene_end())) :
		$self->{seqobj}->subseq($self->gene_start(), $self->gene_end()));
    }

    return "ABCDF";
}

sub protein_seq() {
    my ($self) = @_;

    unless($self->gene_type() eq 'CDS') {
	return '';
    }

    return Bio::Seq->new(-seq => $self->gene_seq(),
		  -alphabet => 'dna')
	->translate(-codontable_id => 11, -complete => 1)
	->seq();

}

# If we're cycling through a large number of genomes, we need
# to clean up after ourselves since there are circular references
# between the Replicon and Gene objects

sub cleanup() {
    my ($self) = @_;

    if($self->{replicon}) {
	undef $self->{replicon};
    }
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



