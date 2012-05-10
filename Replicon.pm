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

package MicrobeDB::Replicon;

#The Replicon class contains features that are associated with a single replicon (chromosome or plasmid) within an organism.
#perldoc Replicon - for more information (or see end of this file)

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");

use strict;
use warnings;
use Carp;


use MicrobeDB::Gene;
use MicrobeDB::GenomeProject;
require MicrobeDB::Search;

use Log::Log4perl qw(get_logger :nowarn);
my $logger = Log::Log4perl->get_logger();

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

@replicon = qw(
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
  rep_size
  rna_num
  file_types
  rep_seq
  distance_calculated
);


@version = qw(
  version_id
  dl_directory
  version_date
  used_by
);

#puts all fields relavant to the database in a single array and removes duplicates
@_db_fields = (@replicon, @version);
my %temp;
@temp{@_db_fields} =();
@_db_fields = keys %temp; 


#store the db tablenames that are used in this object
@_tables = qw(
replicon
version
);


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

# Needed for outputting fasta files,
# these are the allowed substitutions in the string
my %header_lookup = (
    'gene_id'    => '$gene->gene_id',
    'ref'        => '$gene->protein_accnum',
    'gi'         => '$gene->pid',
    'rpv_id'     => '$gene->rpv_id',
    'gpv_id'     => '$gene->gpv_id',
    'start'      => '$gene->gene_start',
    'end'        => '$gene->gene_end',
    'length'     => '$gene->gene_length',
    'locus_tag'  => '$gene->locus_tag',
    'desc'       => '$gene->gene_product',
    'rep_desc'   => '$self->definition',
    'rep_accnum' => '$self->rep_accnum',
    'rep_type'   => '$self->rep_type', 
);

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

	if (!defined($search_obj)) {
		$logger->error("Genome Project is missing!?");
	}

	my ($gpo) = $search_obj->object_search($self);

	if (!defined($gpo)) {
		$logger->error($self->rep_accnum, " is missing in GenomeProject");
	}

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
		$logger->logcroak("Only a Gene object or hash can be used to add a Gene");
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

sub write_fasta {
    my ($self, %args) = @_;

    my $outfile = $args{'filename'} || $self->file_name;

    my $append = $args{'append'} || 0;

    my $seqtype = $args{'seqtype'} || 'protein';

    my $headerfmt = $args{'headerfmt'} || 'gi|#gi#|ref|#ref#| #desc# [#rep_desc#]';

    # If the user already gave the filename an extension
    # don't tack one on
    unless($outfile =~ /\.\S{3}$/) {
	$outfile .= ($seqtype eq 'protein' ? '.faa' : '.ffn');
    }

    # Build the outfile name
    my $writeline = ($append?'>':'') . ">$outfile";

    open(OUT, $writeline) or
	croak "Error opening fasta file $outfile: $!\n";

    foreach my $gene (@{$self->genes()}) {
	unless(ref($gene) eq 'MicrobeDB::Gene') {
	    croak "Only a Gene object can be returned here, this is a " . ref($gene);
	}

	next if(($seqtype eq 'protein') && !($gene->protein_seq));
	next if(($seqtype eq 'dna') && !($gene->gene_seq));

	# Evaluate the header format string
	(my $header = $headerfmt) =~ s/#(\w+)#/$header_lookup{$1}/gee;
	print OUT ">$header\n";
	print OUT join("\n", grep { $_ } split(/(.{1,70})/,
		      ($seqtype eq 'protein'?$gene->protein_seq:$gene->gene_seq)));
	print OUT "\n";
    }

    close OUT;
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

