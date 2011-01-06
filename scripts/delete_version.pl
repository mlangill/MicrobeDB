#!/usr/bin/perl

use warnings;
use strict;

#relative link to the api
use lib "../../";

use MicrobeDB::FullUpdate;

my $usage = "./delete_version.pl <version_id>\n";

my $version_id = $ARGV[0];

unless ( defined($version_id) ) {
	print $usage;
	exit;
}
print "Are you sure you want to delete the loaded mysql version $version_id?(y,n): ";
my $confirm = <STDIN>;
chomp($confirm);

if ( $confirm eq 'y' ) {
	print "Do you also want the flat files deleted?(y,n): ";
	my $confirm2 = <STDIN>;
	chomp($confirm2);
	my $save_files = 1;
	if ( $confirm2 eq 'y' ) {
		print "Deleting records in mysql and deleting flat files. Please wait.\n";
		$save_files = 0;
	} else {
		print "Deleting records in mysql. Flat files will remain untouched. Please wait.\n";
	}
	my $up_obj = new MicrobeDB::FullUpdate( dl_directory => '/' );
	my $notice = $up_obj->delete_version( $version_id, $save_files );
	if ($notice) {
		print "Version $version_id has been successfully removed.\n";
	}
} else {
	print "Version $version_id was not properly confirmed and was not deleted.\n";
}

