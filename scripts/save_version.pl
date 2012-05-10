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

use warnings;
use strict;
use Cwd qw(abs_path getcwd);
use Pod::Usage;
use Log::Log4perl;
use Getopt::Long;
use Carp;

# Find absolute path of script
BEGIN{
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

#relative link to the api
use lib "../../";
use MicrobeDB::Version;
use MicrobeDB::Search;

my ($version_id,$name,$logger_cfg,$help);
my $res = GetOptions(
    "username=s" => \$name,
    "version=i"=> \$version_id,
    "logger=s" => \$logger_cfg,
    "help"=>\$help,
    ) or pod2usage(2);

pod2usage(-verbose=>2) if $help;

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

if(defined $version_id ){
    unless(defined $name){
	    $name = `whoami`;
	    chomp($name);
    }

}else{
    my $so = new MicrobeDB::Search();
    my @vo = $so->object_search(new MicrobeDB::Version());
    
    my $str = join("\t",'Version ID','Download Directory', 'Used By');
    print "\n". $str,"\n";
    foreach(@vo){
	my $str = join("\t",$_->version_id(),$_->dl_directory(),$_->used_by()||'');
	print $str,"\n";
    }
    print "\nPlease enter the Version ID that you would like saved:\n";
    $version_id = <STDIN>;
    chomp($version_id);


    unless($name){
	print "\nPlease enter your name (or to unsave type 'null') or press enter to use your user name:\n";
	$name = <STDIN>;
	chomp($name);	
    }

    if(!defined $name || $name eq ''){
	    $name = `whoami`;
	    chomp($name);
    }

}
$logger->logcroak("No version id provided!") if !defined $version_id || $version_id eq '';

my $vo=new MicrobeDB::Version(version_id=>$version_id);

my $notice =  $vo->save_version($name);

if($notice){
    $logger->info("Version $version_id was saved under the name $name.\nNote:To unsave this version later, use the username 'null'.");
}else{
    $logger->fatal("For some reason version $version_id could NOT be saved under the name $name!");
}

__END__

=head1 Name

save_version.pl - Does a complete update of MicrobeDB.

=head1 USAGE

save_version.pl [-l <logger.conf> -h]  [-v <version_id> -u <name>]

E.g.

#run interactively (displays table of existing versions)

save_version.pl

#provide version id via command line instead of interactive mode 

save_version.pl -v 23

#specify username (instead of computer username)

save_version.pl -v 23 -u morgan


=head1 OPTIONS
  
=over 4

=item B<-v, --version <version_id>>

Specify the version id to be saved.

=item B<-u, --username <name>>

Specify the username that the version should be saved under.

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<save_version.pl> This allows a version of MicrobeDB to be "saved" under a user's name. This only protects the files and data in the database when using the "delete_version.pl" tool.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

