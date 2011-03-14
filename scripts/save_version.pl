#!/usr/bin/perl
#This allows a version of MicrobeDB to be "saved" under a user's name. This only protects the files and data in the database when using the "delete_version.pl" tool.

#use warnings;
use strict;

#relative link to the api
use lib "../../";
use MicrobeDB::Version;
use MicrobeDB::Search;

my $so = new MicrobeDB::Search();
my @vo = $so->object_search(new MicrobeDB::Version());

my $str = join("\t",'Version ID','Download Directory', 'Used By');
print "\n". $str,"\n";
foreach(@vo){
    my $str = join("\t",$_->version_id(),$_->dl_directory(),$_->used_by());
    print $str,"\n";
}
print "\nPlease enter the Version ID that you would like saved:\n";
my $version_id = <STDIN>;
chomp($version_id);

print "\nPlease enter your name (or to unsave type 'null') or press enter to use your user name:\n";
my $name = <STDIN>;
chomp($name);

unless($name){
    $name = `whoami`;
    chomp($name);
}

my $vo=new MicrobeDB::Version(version_id=>$version_id);
my $notice =  $vo->save_version($name);

if($notice){
    print "\nVersion $version_id was saved under the name $name.\nNote:You can unsave a version by using 'null' as the username.\n\n";
}else{
    print "\nVersion $version_id was NOT saved under the name $name!!!!\n\n";
}

