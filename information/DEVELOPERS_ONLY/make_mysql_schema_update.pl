#!/usr/bin/perl

use warnings;
use strict;
use File::Copy;
#Note I am "use"ing this so that this script fails if SQL::Translator is not installed which 'sqlt-diff' is a part of. 
use SQL::Translator;

use lib "../../";
use MicrobeDB::Search;
use autodie;

#get current database schema version
my $so=new MicrobeDB::Search();
my ($result)=$so->table_search('microbedb_meta',{meta_key=>'schema_version'});

my $schema_version=$result->{meta_value};

die unless defined($schema_version);

my $new_schema_version= $schema_version+1;

my $path = '/home/mlangill/Dropbox/projects/MicrobeDB/information/';
my $old_sql = $path."/DEVELOPERS_ONLY/microbedb_schema_old.sql";
my $old_tmp_sql = $old_sql .'.tmp';
my $new_sql = $path."/INSTALL/microbedb_schema.sql";
my $update_sql = $path."/UPDATE/schema_updates/update_schema_v".$new_schema_version.".sql";

move($new_sql,$old_tmp_sql);

#dump only the schemas
system("mysqldump -d --skip-opt microbedb gene genomeproject microbedb_meta replicon taxonomy version> $new_sql");

#compare the old and new schemas and make the update schema code
system("sqlt-diff $old_sql=MySQL $new_sql=MySQL > $update_sql");

open(my $FH,$update_sql);
my @changes=<$FH>;
my ($no_change)=grep(/No differences found/,@changes);

if(!$no_change){
    print "Changes detected in schema, so creating new schema version: $new_schema_version\n";
    #update the schema_version number in the database
    my $dbh = MicrobeDB::MicrobeDB->_db_connect();
    my $sql = "UPDATE microbedb_meta SET meta_value=$new_schema_version WHERE meta_key='schema_version'";
    $dbh->do($sql);
    move($old_tmp_sql,$old_sql);
}else{
    #no changes
    print "No changes in schema detected.\n";
    unlink($old_tmp_sql,$update_sql);
}
#Only data we want the user to load is the stuff in microbedb_meta so dump it here
system("mysqldump --no-create-info --skip-opt microbedb microbedb_meta >>$new_sql");
