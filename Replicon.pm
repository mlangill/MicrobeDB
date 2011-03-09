package MicrobeDB::Replicon;

#The Replicon class contains features that are associated with a single replicon (chromosome or plasmid) within an organism.
#perldoc Replicon - for more information (or see end of this file)

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use strict;
use warnings;
use Carp;


use MicrobeDB::Gene;
require MicrobeDB::Search;

my @FIELDS;
my @replicon;
my @version;
my @_db_fields;
my @_tables;
my %_field_hash;
BEGIN {

#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

my @replicon = qw(
  rpv_id
  gpv_id
  version_id
  rep_accnum
  definition
  rep_type
  rep_ginum
  file_name
  cds_num
  gene_num
  protein_num
  genome_id
  rep_size
  rna_num
  file_types
  rep_seq
);

my @version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
my @_db_fields = (@replicon, @version);
my %temp;
@temp{@_db_fields} =();
@_db_fields = keys %temp; 


#store the db tablenames that are used in this object
my @_tables = qw(
replicon
version
);

my %_field_hash;
$_field_hash{replicon} = \@replicon;
$_field_hash{version}  = \@version;

#fields not directly related to the database
my @_other = qw(
  genes
  gene_index
);

@FIELDS = ( @_db_fields, @_other );
}

use fields  @FIELDS;

sub new {
	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

	#set the gene index to the first of the array
	$self->gene_index(0);

	#Set each attribute that is given as an arguement
	foreach my $attr ( keys(%arg) ) {

		#Need special case when setting the genes attribute
		#(note: we want to store this as a reference of an array of Gene objects but,
		#this check will handle if a plain hash is given (ie. the gene hashes are not blessed as Gene))
		if ( $attr eq 'genes' ) {

		 #check each of the genes to see if it is an actuall Gene object
			for ( my $i = 0 ; $i < scalar( @{ $arg{$attr} } ) ; $i++ ) {
				unless ( ref( $arg{$attr}->[$i] ) eq 'MicrobeDB::Gene' ) {
					
	 				#overwrite the normal hash reference with the new Gene object reference
					$arg{$attr}->[$i] = new MicrobeDB::Gene( %{ $arg{$attr}->[$i] } );
				}
			}
		}

		#set the attribute in the object
		$self->$attr( $arg{$attr} );
	}
	return $self;
}

#Returns the path and filename to a single file for this replicon
#The user must provide the suffix of the filetype they want (eg. fna ptt asn etc)
#undef is returned if that file is not available for that replicon (based on the file_types field)
sub get_filename {
	my ($self,$file_suffix)=@_;
	
	#check to see if the file type is available for this replicon
	unless($self->file_types =~ /( |^)\.$file_suffix( |$)/){
		return undef;	
	}
	my $search_obj = new MicrobeDB::Search(return_obj => 'MicrobeDB::GenomeProject');
	my ($gpo) = $search_obj->object_search($self);
	my $file_name = $gpo->gpv_directory() . $self->file_name() . ".$file_suffix";
	
	#small hack since symbolic links will not work when called by php from web browser
	unless($file_name =~ /home.westgrid/){
	    if($file_name =~ /home\/shared/){
	        $file_name =~ s/home/home.westgrid/;
	    }
	}
	return $file_name;
}

#adds a gene object (or a hash that can be converted to a gene object) to the array of genes for this replicon
sub add_gene {
	my ( $self, $gene ) = @_;
	my $gene_obj;
	if ( ref($gene) eq 'MicrobeDB::Gene' ) {
		$gene_obj = $gene;
	} elsif ( ref($gene) eq 'HASH' ) {
		$gene_obj = new MicrobeDB::Gene(%$gene);
	} else {
		croak "Only a Gene object or hash can be used to add a Gene";
	}
	push( @{ $self->{genes} }, $gene_obj );
}

#retrieves the next gene for this replicon
sub next_gene {
	my ($self) = @_;

	#get the gene index
	my $gene_index = $self->gene_index();

	#get the array of all gene objects
	my @genes = @{ $self->genes() };

	#return the gene object if the rep index is still within bounds
	my $ret_gene;
	if ( $gene_index < scalar(@genes) ) {
		$ret_gene = $genes[$gene_index];
		$self->gene_index( $gene_index++ );
	}
	return $ret_gene;
}

#returns an array of fields
#all fields are returned if a table name is not given
sub field_names{
	my ($self, $table_name)=@_;
	unless(defined($table_name)){
		return @FIELDS
	}
	if($table_name eq 'replicon'){ return @replicon}
	if($table_name eq 'version'){return @version}
	#special case
	if($table_name eq 'db'){return @_db_fields}
	return;
}
sub _retrieve_genes{
    my ($self) =@_;
    my $so = new MicrobeDB::Search();
    my @genes = $so->object_search( new MicrobeDB::Gene(rpv_id => $self->rpv_id()));
    return \@genes;
}

sub genes{
#returns, sets, and finds replicons associated with this replicon
    my ($self,$new_genes) = @_;

    #Set the new value for the attribute if available (stored as a reference to an array)
    $self->{genes} = $new_genes if defined($new_genes);

    if(defined($self->{genes})){
	return $self->{genes};
    }else{
        return $self->_retrieve_genes();
    }
}

#returns, sets, and finds replicon sequence associated with this replicon
sub rep_seq{
    my ($self,$rep_seq) = @_;

    #Set the new value for the attribute if given
    $self->{rep_seq} = $rep_seq if defined($rep_seq);

    if(defined($self->{rep_seq})){
	return $self->{rep_seq};
    }else{
        return $self->_retrieve_rep_seq();
    }
}

sub _retrieve_rep_seq{
    my ($self) =@_;
    my $so = new MicrobeDB::Search(return_seqs=>1);
    my ($replicon) = $so->object_search( new MicrobeDB::Replicon(rpv_id => $self->rpv_id()));
    
    return $replicon->rep_seq();
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

Replicon: contains features that are associated with a single replicon (chromosome or plasmid) within an organism

=head1 Synopsis

=head1 AUTHOR

Morgan Langille

=head1 Date Created

June 2nd, 2006

=cut

