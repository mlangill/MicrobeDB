package MicrobeDB::Versions;

# Version contains search functionality for available versions of MicrobeDB
# along with routines to find replicon differences between versions.

use strict;
use warnings;

#inherit common methods and fields from the MicroDB class
use base ("MicrobeDB::MicrobeDB");
use Data::Dumper;

use MicrobeDB::Search;
use MicrobeDB::Version;
use Carp;

sub new {
    my ( $class, %arg ) = @_;

    #Bless an anonymous empty hash
    my $self = bless {}, $class;

    # Even as the database grows over the years the version table
    # should remain quite small, so slurp it down.
    my $so = new MicrobeDB::Search();
    my @versions = sort {$a->version_id cmp $b->version_id } $so->object_search( new MicrobeDB::Version());
    $self->{versions} = \@versions;

    # Save the mappings of actual version numbers to where they are
    # in the index
    for(my $i = 0; $i <= $#versions; $i++) {
	$self->{index_map}->{$versions[$i]->version_id} = $i;
    }

    $self->index(0);

    print Dumper $self->{versions};

    return $self;
}

sub next_version {
    my ($self) = @_;

    # get the current index
    my $index = $self->{version_index};

    return undef if($index >= scalar(@{$self->{versions}}));

    my $ver = $self->{versions}->[$index];
    $self->{version_index}++;

    return $ver;
}

sub get_versions {
    my ($self) = @_;

    my @keys = sort keys (%{$self->{index_map}});
    return @keys;
}

sub get_version {
    my ($self, $ver) = @_;

    # If a version is defined get that version
    return $self->{versions}[$self->{index_map}->{$ver}]
	if(defined($ver) && defined($self->{index_map}->{$ver}));

    # Otherwise get the current version based on the index
    return $self->{versions}[$self->{version_index}] if($self->{version_index} <= $#{$self->{versions}});

    return undef;
}

# Compare the $updatedver against $basever and show what has changed
# compared to the $basever.  If no parameters are given it will default
# to $updatedver being the newest version and $basever being the 
# immediately prior version
sub version_changes {
    my ($self, $updatedver, $basever) = @_;

    unless(defined($updatedver) && defined($basever)) {
	# Get newest two versions
	my @vers = $self->get_versions();
	$updatedver = pop @vers;
	$basever = pop @vers;
    } else {
	return undef unless($self->get_version($updatedver) && 
			    $self->get_version($basever));
    }

    my $base_hash = $self->_get_version_hash($basever);
    my $updated_hash = $self->_get_version_hash($updatedver);

    my $newrec; my $changed; my $deleted;
    foreach my $acc (keys %{$updated_hash}) {
	if(defined $base_hash->{$acc}) {
	    # We have an intersection, has it changed?
	    # Yes it has if the following is true
	    $changed->{$acc} = $updated_hash->{$acc}
	      if($updated_hash->{$acc}->{ver} ne $base_hash->{$acc}->{ver});
	} else {
	    # Ok, it's new!
	    $newrec->{$acc} = $updated_hash->{$acc};
	}
    }

    # Now unfortunately we have to loop backwards to find all the deleted
    foreach my $acc (keys %{$base_hash}) {
	$deleted->{$acc} = $base_hash->{$acc}
	  unless(defined $updated_hash->{$acc});
    }

    return ($newrec, $changed, $deleted);
}

sub _get_version_hash {
    my ($self, $ver) = @_;

    my $dbh = $self->_db_connect();
    my $sth = $dbh->prepare("SELECT replicon.rep_accnum, replicon.rpv_id, replicon.gpv_id, genomeproject.taxon_id FROM replicon, genomeproject WHERE genomeproject.gpv_id = replicon.gpv_id AND genomeproject.version_id = ? AND replicon.version_id = ?");
    $sth->execute($ver, $ver);

    my $ver_hash;

    while(my @row = $sth->fetchrow_array) {
	my ($accnum, $ver) = split '\.', $row[0];
	$ver_hash->{$accnum}->{ver} = $ver;
	$ver_hash->{$accnum}->{rpv_id} = $row[1];
	$ver_hash->{$accnum}->{gpv_id} = $row[2];
	$ver_hash->{$accnum}->{taxon_id} = $row[3];
    }

    return $ver_hash;
}

sub index {
    my ($self, $newvalue) = @_;

    return -1 if(defined($newvalue) && $newvalue >= scalar(@{$self->{versions}}));
    return -1 if($self->{version_index} >= scalar(@{$self->{versions}}));

    $self->{version_index} = $newvalue if(defined($newvalue));

    return $self->{version_index};
}

sub max_index {
    my ($self) = @_;

    return $#{$self->{versions}};
}

1;

