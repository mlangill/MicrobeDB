package navigator;

#a package for navigating directories and files
#results are typically returned as an array
use File::Find;
use File::Basename;
use strict;

our (@ISA, @EXPORT, @EXPORT_OK);
use Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(get_allfiles_byext get_allfiles_byname get_allfiles_byfullname get_files_byext get_allsubdirs get_subdirs);
@EXPORT_OK = qw(get_allfiles_byext get_allfiles_byname get_allfiles_byfullname get_files_byext get_allsubdirs get_subdirs extension);

#get all files of a certain type from a parent directory
#recursively go down all directories and return full path
#to each file 
sub get_allfiles_byext{
    my $parentdir = shift;
    my @types = @_;
    my @files;
    my %types = &array2hash(@types);
    find ({wanted=> sub {push @files, $File::Find::name if (-f && $types{&extension($_)})}, follow_fast => 1}, $parentdir);
    return @files;   
}

#get all files in a parent directory
#does not drill down to next level
sub get_files_byext{
    my $parentdir = shift;
    my @types = @_;
    my @files;
    my %types = &array2hash(@types);
    opendir (DIR, $parentdir) or die "Can not open directory $parentdir\n";
    while (defined (my $file = readdir(DIR))){
	if (-f "$parentdir/$file"){
	    my $ext = &extension("$parentdir/$file");
	    if ($types{$ext}){
		push @files, "$parentdir/$file";
	    }
	}
    }
    return @files;
}

#give a file name and a parent dir
#return the full paths to the files with
#that name
sub get_allfiles_byfullname{
    my $parentdir = shift;
    my $filename = shift;
    my @files;
    find ({wanted=> sub {push @files, $File::Find::name if (-f && (basename($_) eq $filename))}, follow_fast => 1}, $parentdir);
    return @files;  
}

#get all files with names matched to the pattern
#return an array of the full path to each file
sub get_allfiles_byname{
    my $parentdir = shift;
    my $filename = shift;
    my @files;
    find ({wanted=> sub {push @files, $File::Find::name if (-f && (basename($_)=~/$filename/))}, follow_fast => 1}, $parentdir);
    return @files;  
}

#get all directories in a parent directory
#recursively go down all directories and return full path
#to each directory
sub get_allsubdirs{
    my $parentdir = shift;
    my @dirs;
    find ({wanted=> sub {push @dirs, $File::Find::name if -d}, follow_fast => 1}, $parentdir);
    shift @dirs; #remove the parentdir
    return @dirs;
}

#get all sub-directories in the parent directory
sub get_subdirs{
    my $parentdir = shift;
    my @subdirs;
    opendir (DIR, $parentdir) or die "Can not open directory $parentdir\n";
    while (defined (my $file = readdir(DIR))){
	if (-d "$parentdir/$file"){
	    push @subdirs, "$parentdir/$file";
	}
    }
    return @subdirs;
}

sub array2hash{
    my %hash;
    foreach (@_){
	$hash{$_}=1;
    }
    return %hash;
}


sub extension {
    my $path = shift;
    my $ext = (fileparse($path,'\..*'))[2];
    $ext =~ s/^\.//;
    return $ext;
}    

1;
