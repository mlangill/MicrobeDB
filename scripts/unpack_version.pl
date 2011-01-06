#!/usr/bin/perl
#Unpacks (tar/gzip) genome files from ftp download
#This is usually run after download_version.pl (by the download_load_and_delete_old_version.pl)

use strict;
use warnings;

#directory containing the newly downloaded ftp files
my $dir = $ARGV[0];
unless ( -d $dir ) {
	print "Input the directory containing the downloaded organisms from NCBI.\n";
	exit;
}

chdir($dir);
my @compressed_files = glob($dir .'/all.*');
for(@compressed_files){
	my $status= system("tar xzf $_");
	unlink($_) if $status == 0;
}
