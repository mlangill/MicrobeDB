#!/usr/bin/env perl
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

#Deletes a version from MicrobeDB (with optionally choice of also deleting the flat files in addition to the MySQL data)

use warnings;
use strict;
use Cwd qw(abs_path getcwd);
use Pod::Usage;
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

my ($all_unused,$logger_cfg,$help,$delete_files,$no_confirm,$force);
my $res = GetOptions("all_unused" => \$all_unused,
		     "force" => \$force,
		     "no_confirm" => \$no_confirm,
		     "delete_files"=>\$delete_files,
		     "logger=s" => \$logger_cfg,
		     "help"=>\$help,
    ) or pod2usage(2);

pod2usage(-verbose=>2) if $help;

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

my %possible_version_ids;
unless(defined($version_id)){
    my $so = new MicrobeDB::Search();
    my @vo = $so->table_search('version');

    my $str = join("\t",'Version ID','Download Directory', 'Used By');
    print "\n". $str,"\n";

    foreach(@vo){
	my $used_by = $_->{used_by} ||'';
	$possible_version_ids{$_->{version_id}}=1;
	my $str = join("\t",$_->{version_id},$_->{dl_directory},$used_by);
	print $str,"\n";
    }
    print "\nPlease enter the Version ID that you would like deleted (separate multiple versions with comma):\n";
    $version_id = <STDIN>;
    chomp($version_id);
    pod2usage($0.': You must specify a valid version id.') if $version_id eq '';
    
}

my @version_ids=split(/,/,$version_id);

foreach(@version_ids){
    unless(exists $possible_version_ids{$_}){
	pod2usage($0.': You must specify a valid version id.');
    }
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
    foreach my $version_id (@version_ids){
	my $vo = new MicrobeDB::Version( version_id=>$version_id );
	my $notice = $vo->delete_version( $save_files, $force );
	if ($notice) {
	    print "Version $version_id has been successfully removed.\n";
	}
    }
} else {
	print "Version $version_id was not properly confirmed by user and was not deleted.\n";
}

__END__

=head1 Name

delete_version.pl - Removes a MicrobeDB version.

=head1 USAGE

delete_version.pl [-a -f -n -d -l <log config> -h] [<version_id>] 

E.g.

#run interactively (displays table of existing versions)

delete_version.pl


#Specify version to delete directly

delete_version.pl 23


#Flat files are removed in addition to MySQL version

delete_version.pl -d 23


#No interactive prompt to confirm deletion

delete_version.pl -n -d 23

=head1 OPTIONS

=over 4

=item B<-a, --all_unused>

Removes all unused versions except for the two most recent ones.

=item B<-n, --no_confirm>

Removes version without interactive confirmation prompt.

=item B<-d, --delete_files>

Removes files associated with this version in addition to data in the database. 

=item B<-f, --force>

Removes version even if it has been 'saved'.

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<delete_version.pl> This script removes versions from MicrobeDB. MicrobeDB stores each update of downloaded files with a unique version id. Versions may need to be removed manually if an update failed or manual clean up is required. Old versions are deleted automatically by download_load_and_delete_old_version.pl.
Note that if a version has been "saved" by using "save_version.pl", then it will not be deleted unless --force option is used. 

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

