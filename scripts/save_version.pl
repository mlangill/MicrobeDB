#!/usr/bin/perl

#use warnings;
use strict;

#relative link to the api
use lib "../../";
use MicrobeDB::FullUpdate;


my $so = new MicrobeDB::Search();
my @vo = $so->table_search('version');

my $str = join("\t",'Version ID','Download Directory', 'Used By');
print "\n". $str,"\n";
foreach(@vo){
    my $str = join("\t",$_->{version_id},$_->{dl_directory},$_->{used_by});
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

my $up_obj = new MicrobeDB::FullUpdate( dl_directory => '/' );
my $notice =  $up_obj->save_version($version_id, $name);

if($notice){
    print "\nVersion $version_id was saved under the name $name.\nNote:You can unsave a version by using 'null' as the username.\n\n";
}else{
    print "\nVersion $version_id was NOT saved under the name $name!!!!\n\n";
}

