#!/usr/bin/perl
#Deletes a version from MicrobeDB (with optionally choice of also deleting the flat files in addition to the MySQL data)

use warnings;
use strict;
use Cwd qw(abs_path getcwd);

use Log::Log4perl;
use Getopt::Long;

# Find absolute path of script
BEGIN{
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};


#relative link to the api
use lib "../../";
use MicrobeDB::FullUpdate;
use MicrobeDB::Version;

my ($all_unused,$logger_cfg,$help,$force,$delete_files,$no_confirm);
my $res = GetOptions("all_unused" => \$all_unused,
		     "force" => \$force,
		     "no_confirm" => \$no_confirm,
		     "delete_files"=>\$delete_files,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    );

my $usage = "Usage: 
$0 [-a] [-f] [-n] [-d] [-l <logger config file>] [-h] <version_id> \n";

my $long_usage = $usage.
    "Options:
-a or --all_unused : Removes all unused versions except for the two most recent ones (files are removed if not shared with other versions).
-f or --force : Removes version even if it has been 'saved'.
-n or --no_confirm : Removes version without confirmation prompt.
-d or --delete_files : Removes files associated with this version along with mysql (does not check if files are shared with other versions). 
-l or --logger <logger config file>: alternative logger.conf file
-h or --help : Show more information for usage.
";
die $long_usage if $help;

my $version_id = $ARGV[0];

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

if($all_unused){
    my $vo= new MicrobeDB::Version();
    $vo->delete_unused_versions();
    
    exit;
}

unless(defined($version_id)){
    my $so = new MicrobeDB::Search();
    my @vo = $so->table_search('version');

    my $str = join("\t",'Version ID','Download Directory', 'Used By');
    print "\n". $str,"\n";
    foreach(@vo){
	my $used_by = $_->{used_by} ||'';
	my $str = join("\t",$_->{version_id},$_->{dl_directory},$used_by);
	print $str,"\n";
    }
    print "\nPlease enter the Version ID that you would like deleted:\n";
    $version_id = <STDIN>;
    chomp($version_id);
}
unless ( defined($version_id) ) {
	print $usage;
	exit;
}

my $confirm;
my $confirm_delete_files;
if($no_confirm){
    $confirm='y';
}else{
    print "Are you sure you want to delete the loaded mysql version $version_id?(y,n): ";
    $confirm = <STDIN>;
    chomp($confirm);
}

if ( $confirm eq 'y' ) {
    if($delete_files){
	$confirm_delete_files='y';
    }else{
	print "Do you also want the flat files deleted?(y,n): ";
	$confirm_delete_files = <STDIN>;
	chomp($confirm_delete_files);
    }
    my $save_files = 1;
    if ( $confirm_delete_files eq 'y' ) {
	print "Deleting records in mysql and deleting flat files. Please wait.\n";
	$save_files = 0;
    } else {
	print "Deleting records in mysql. Flat files will remain untouched. Please wait.\n";
    }
	my $vo = new MicrobeDB::Version( version_id=>$version_id );
	my $notice = $vo->delete_version( $save_files );
	if ($notice) {
		print "Version $version_id has been successfully removed.\n";
	}
} else {
	print "Version $version_id was not properly confirmed by user and was not deleted.\n";
}

