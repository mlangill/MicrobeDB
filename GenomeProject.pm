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
require MicrobeDB::Search;

use Log::Log4perl qw(get_logger :nowarn);
my $logger = Log::Log4perl->get_logger();


my @FIELDS;
my @_db_fields;
my %_field_hash;
my @_tables;
my @genomeproject;
my @taxonomy;
my @version;
BEGIN{
#All fields in the following arrays correspond to the fields in the database

#Each array represents one table in the database

#Duplicate field names *should* all represent the same piece of data (usually just a foreign key);
#therefore, only a single copy for that field will be stored in the object and all others will be clobbered.

#The array names must be kept the same as the database names (otherwise alter field_names())
@genomeproject = qw(
  gpv_id
  gp_id
  version_id
  taxon_id
  org_name
  gram_stain
  genome_gc
  patho_status
  disease
  genome_size
  chromosome_num
  contig_num
  plasmid_num
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

@taxonomy = qw(
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

@version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
@_db_fields = ( @genomeproject, @taxonomy, @version );
my %temp;
@temp{@_db_fields} = ();
@_db_fields = keys %temp;

#store the db tablenames that are used in this object
@_tables = qw(
  genomeproject
  taxonomy
  version
);

#fields not directly related to the database
my @_other = qw(
  replicons
  rep_index
);

$_field_hash{genomeproject} = \@genomeproject;
$_field_hash{taxonomy} = \@taxonomy;
$_field_hash{version}  = \@version;

@FIELDS = ( @_db_fields, @_other );
}

use fields  @FIELDS;


sub new {

	my ( $class, %arg ) = @_;

	#bless and restrict the object
	my $self = fields::new($class);

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
		} elsif ($attr eq 'genome_size') {
			# We have to test genome_size and genome_gc to see if they're
			# null, otherwise when it tries to retreive the replicons
			# to calculate it and gpv_id isn't yet set bad things happen.
			# (infinite loop)
			next unless$arg{$attr};			
		} elsif ($attr eq 'genome_gc') {
			next unless$arg{$attr};			
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
		$logger->logcroak("Only a MicrobeDB::Replicon object or hash can be used to add a Replicon");
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

    # In case a genome didn't load properly and we don't
    # get back a proper object, we DON'T want to search
    # with no gpv_id, ugh, not good.
    return () unless( $self->{gpv_id});

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

sub delete{
    my($self)=@_;
    my $dbh=$self->_db_connect();
    
    my $gpv_id=$self->gpv_id();
    if(defined($gpv_id)){
	#list of tables to delete records from
	my @tables_to_delete = qw/genomeproject replicon gene/;
	
	#delete records corresponding to gpv_id (use QUICK since there are millions of genes)
	foreach my $curr_table (@tables_to_delete) {
	    $dbh->do("DELETE QUICK FROM $curr_table WHERE gpv_id = $gpv_id ");
	}
    }
}

sub plasmid_num{
   my ($self,$value)=@_;
    $self->{plasmid_num} = $value if defined($value);
    
    unless(defined($self->{plasmid_num})){
	$self->plasmid_num($self->_count_plasmid_num());
    }

    return $self->{plasmid_num};
}

sub _count_plasmid_num{
    my ($self)=@_;
    my $plasmid_num=0;
    foreach my $rep (@{$self->replicons()}){
	if($rep->rep_type() eq 'plasmid'){
	    $plasmid_num++;
	}   
    }
    return $plasmid_num;
}

sub contig_num{
   my ($self,$value)=@_;
    $self->{contig_num} = $value if defined($value);
    
    unless(defined($self->{contig_num})){
	$self->contig_num($self->_count_contig_num());
    }

    return $self->{contig_num};
}

sub _count_contig_num{
    my ($self)=@_;
    my $contig_num=0;
    foreach my $rep (@{$self->replicons()}){
	if($rep->rep_type() eq 'contig'){
	    $contig_num++;
	}   
    }
    return $contig_num;
}

sub chromosome_num{
   my ($self,$value)=@_;
    $self->{chromosome_num} = $value if defined($value);
    
    unless(defined($self->{chromosome_num})){
	$self->chromosome_num($self->_count_chromosome_num());
    }

    return $self->{chromosome_num};
}

sub _count_chromosome_num{
    my ($self)=@_;
    my $chromosome_num=0;
    foreach my $rep (@{$self->replicons()}){
	if($rep->rep_type() eq 'chromosome'){
	    $chromosome_num++;
	}   
    }
    return $chromosome_num;
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



