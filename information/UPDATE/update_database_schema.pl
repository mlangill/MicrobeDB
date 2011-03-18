#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Cwd qw(abs_path getcwd);


BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

#relative link to the api
use lib "../../";
use MicrobeDB::Search;



#get current database schema version
my $so=new MicrobeDB::Search();
my ($result)=$so->table_search('microbedb_meta',{meta_key=>'schema_version'});

my $schema_version=$result->{meta_value};

if(defined($schema_version)){
    print "You are currently using MicrobeDB schema version: $schema_version\n";
}else{
    die "Can't find schema version in your MicrobeDB";
}

my @update_files = glob('schema_updates/*.sql');

#Get a list of all updates
my @schema_updates;
foreach my $update(@update_files){
    if($update =~/update_schema_v(\d+)\.sql/){
	push(@schema_updates,$1);
    }else{
	warn "Can't parse schema version information from file: $update";
    }
}

@schema_updates=sort{$a<=>$b}@schema_updates;

my $new_version_flag=0;
foreach my $ver_number(@schema_updates){
    if($ver_number > $schema_version){
	$new_version_flag=1;
	print "Your schema is out-of-date, updating to version: $ver_number\n";
	my $update_cmd = 'mysql microbedb < update_schema_v'.$ver_number.'.sql';
	system($update_cmd);

        #update the schema_version number in the database
	my $dbh = MicrobeDB::MicrobeDB->_db_connect();
	my $sql = "UPDATE microbedb_meta SET meta_value=$ver_number WHERE meta_key='schema_version'";
	$dbh->do($sql);

    }
}

print "Your schema is up-to-date.\n" unless $new_version_flag;


