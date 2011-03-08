package MicrobeDB::GenomeProject;

#GenomeProject contains all features that are associated with a single genome project,
#including details about the organism that was sequenced
#perldoc GenomeProject - for more information (or see end of this file)

use strict;
use warnings;

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");


use Carp;

require MicrobeDB::Replicon;

use MicrobeDB::Search;

#our $AUTOLOAD;

#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

#The array names must be kept the same as the database names (otherwise alter field_names())
my @genomeproject = qw(
  gpv_id
  gp_id
  version_id
  taxon_id
  org_name
  lineage
  gram_stain
  genome_gc
  patho_status
  disease
  genome_size
  pathogenic_in
  temp_range
  habitat
  shape
  arrangement
  endospore
  motility
  salinity
  oxygen_req
  release_date
  centre
  gpv_directory
);

my @taxonomy = qw(
  taxon_id
  superkingdom
  phylum
  class
  order
  family
  genus
  species
  other
  synonyms
);

my @version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
my @_db_fields = ( @genomeproject, @taxonomy, @version );
my %temp;
@temp{@_db_fields} = ();
@_db_fields = keys %temp;

#store the db tablenames that are used in this object
my @_tables = qw(
  genomeproject
  taxonomy
  version
);

#fields not directly related to the database
my @_other = qw(
  replicons
  rep_index
);

my %_field_hash;
$_field_hash{genomeproject} = \@genomeproject;
$_field_hash{taxonomy} = \@taxonomy;
$_field_hash{version}  = \@version;

my @FIELDS = ( @_db_fields, @_other );

sub new {

	my ( $class, %arg ) = @_;

	#Bless an anonymous empty hash
	my $self = bless {}, $class;

	#Fill all of the keys with the fields
	foreach (@FIELDS) {
		$self->{$_} = undef;
	}

	#set the replicon index to the first of the array
	$self->rep_index(0);

	#Set each attribute that is given as an arguement (and handle special cases)
	foreach my $attr ( keys(%arg) ) {

#Need special case when setting the replicons attribute
#(note: we want to store this as a reference of an array of Replicon objects but,
#this check will handle if a plain hash is given (ie. the replicon hashes are not blessed as Replicons))
		if ( $attr eq 'replicons' ) {

		 #check each of the replicons to see if it is an actuall Replicon object
			for ( my $i = 0 ; $i < scalar( @{ $arg{$attr} } ) ; $i++ ) {
				unless ( ref( $arg{$attr}->[$i] ) eq 'MicrobeDB::Replicon' ) {

	 #overwrite the normal hash reference with the new Replicon object reference
					$arg{$attr}->[$i] = new MicrobeDB::Replicon( %{ $arg{$attr}->[$i] } );
				}
			}
		}

		#do the same for references
#		if ( $attr eq 'references' ) {

		#check each of the references to see if it is an actual Reference object
	#		for ( my $i = 0 ; $i < scalar( @{ $arg{$attr} } ) ; $i++ ) {
		#		unless ( ref( $arg{$attr}->[$i] ) eq 'Reference' ) {

	 #overwrite the normal hash reference with the new Replicon object reference
			#		$arg{$attr}->[$i] = new Reference( %{ $arg{$attr}->[$i] } );
			#	}
			#}
		#}

		#set the attribute in the object
		$self->$attr( $arg{$attr} );
	}

	return $self;
}

#adds a replicon object (or a hash that can be converted to a replicon object) to the array of replicons for this genome project
sub add_replicon {
	my ( $self, $rep ) = @_;
	my $rep_obj;
	if ( ref($rep) eq 'MicrobeDB::Replicon' ) {
		$rep_obj = $rep;
	} elsif ( ref($rep) eq 'HASH' ) {
		$rep_obj = new MicrobeDB::Replicon(%$rep);
	} else {
		croak "Only a MicrobeDB::Replicon object or hash can be used to add a Replicon";
	}
	push( @{ $self->{replicons} }, $rep_obj );
}

#retrieves the next replicon for this genome project
sub next_replicon {
	my ($self) = @_;

	#get the replicon index
	my $rep_index = $self->rep_index();

	#get the array of all replicon objects
	my @replicons = @{ $self->replicons() };

	#return the replicon object if the rep index is still within bounds
	my $ret_rep;
	if ( $rep_index < scalar(@replicons) ) {
		$ret_rep = $replicons[$rep_index];
		$self->rep_index( ++$rep_index );
	}
	return $ret_rep;
}

#retrieves all replicons for this genome project
sub _retrieve_replicons{
    my ($self) =@_;
    my $rep = new MicrobeDB::Replicon(gpv_id => $self->gpv_id());
    my $so = new MicrobeDB::Search();
    my @reps = $so->object_search($rep);
    return \@reps;
}

#returns, sets, and finds replicons associated with this genome project
sub replicons{
    my ($self,$new_reps) = @_;
    
    #Set the new value for the attribute if available (stored as a reference to an array)
    $self->{replicons} = $new_reps if defined($new_reps);
    
    unless(defined($self->{replicons})){
        $self->replicons($self->_retrieve_replicons());
    }
    #return the current content 
    return $self->{replicons};
}

#returns, sets, and finds genome size associated with this genome project
sub genome_size{
    my ($self,$genome_size)=@_;
    $self->{genome_size} = $genome_size if defined($genome_size);
    
    unless(defined($self->{genome_size})){
	$self->genome_size($self->_calc_genome_size());
    }

    return $self->{genome_size};
}


#calculates the genome size by adding up all the rep sizes
sub _calc_genome_size{
    my ($self)=@_;
    my $genome_size;
    foreach my $rep (@{$self->replicons()}){
	$genome_size+=$rep->rep_size();
    }
    #format the size to be in Mb
    $genome_size = sprintf("%.2f",$genome_size/1000000);
    return $genome_size;
}

#returns, sets, and finds genome gc associated with this genome project
sub genome_gc{
    my ($self,$genome_gc)=@_;
    $self->{genome_gc} = $genome_gc if defined($genome_gc);
    
    unless(defined($self->{genome_gc})){
	$self->genome_gc($self->_calc_genome_gc());
    }

    return $self->{genome_gc};
}


#calculates the genome size by adding up all the rep sizes
sub _calc_genome_gc{
    my ($self)=@_;
    my $genome_gc;
    my $g_count=0;
    my $c_count=0;
    my $genome_size=0;
    foreach my $rep (@{$self->replicons()}){
	if(defined($rep->rep_seq())){
	    $g_count += ($rep->{rep_seq} =~ tr/g//);
	    $g_count += ($rep->{rep_seq} =~ tr/G//);
	    $c_count += ($rep->{rep_seq} =~ tr/c//);
	    $c_count += ($rep->{rep_seq} =~ tr/C//);
	    $genome_size += $rep->rep_size();
	}
    }
    $genome_gc = ($g_count+$c_count)/($genome_size);
    #format the number
    $genome_gc = sprintf("%.2f",$genome_gc*100);
    return $genome_gc;
}

#returns an array of fields
#all fields are returned if a table name is not given
sub field_names {
	my ( $self, $table_name ) = @_;
	unless ( defined($table_name) ) {
		return @FIELDS;
	}

	#special case
	if($table_name eq 'db'){return @_db_fields}
	
	return @{$_field_hash{$table_name}};

	#if($table_name eq 'genomeproject'){ return @genomeproject}
	#if($table_name eq 'version'){return @version}
	#if($table_name eq 'taxonomy'){return @taxonomy}

	#return;
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

GenomeProject: contains all features that are associated with a single genome project, including details about the organism that was sequenced

=head1 Synopsis

=head1 AUTHOR

Morgan Langille

=head1 Date Created

June 5th, 2006

=cut



