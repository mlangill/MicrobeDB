#!/usr/bin/perl

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

#All genomes are downloaded from NCBI using either Aspera (default) or FTP
#Aspera should be much faster, but if you have problems you might want to try using FTP (download_version.pl --ftp <DIR>)

use strict;
use warnings;
use Time::localtime;
use Time::Local;
use File::stat;
use Getopt::Long;
use Log::Log4perl;
use LWP::Simple;
use Config;
use Cwd qw(abs_path getcwd);

BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

my $download_dir; my $logger_cfg; my $ftp_flag;
my $res = GetOptions("directory=s" => \$download_dir,
		     "logger=s" => \$logger_cfg,
                     "ftp" => \$ftp_flag,);

# Find absolute path of script, yes we have to
# do this again because of scope issues
my ($path) = abs_path($0) =~ /^(.+)\//;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
# Set some base logging settings if the logger conf doesn't exist
$logger_cfg = q/
    log4perl.rootLogger = INFO, Screen

    log4perl.appender.Screen                          = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout.ConversionPattern = [%p] (%F line %L) %m%n
/ unless(-f $logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

if($ftp_flag){    
    #Download all genomes from NCBI using FTP
    $download_dir = NCBIftp_wget3($download_dir);
}else{
    #Download all genomes from NCBI using ASPERA
    $download_dir = NCBI_aspera($download_dir);
}

#get_genomeprojfiles($dir);
$logger->info("Using $download_dir");

sub NCBI_aspera{
    my $download_dir= shift;
	
    my $remotedir  = 'genomes/Bacteria/';
#    my $parentdir  = "$download_parent_dir";
#    my $prefix     = 'Bacteria';
#    my @file_types = qw/GeneMark Glimmer3 Prodigal asn cog faa ffn fna frn gbk gff ptt rnt rps rpt val/;
    my @file_types = qw/faa ffn fna frn gbk gff rpt/;
    my $parameters = '';
    my $overwrite  = 0;                                   #default is not to overwrite
    my $get_gprj = 1;    #default is to get the organism info and complete genome files
    my $logdir = $download_dir . 'log/';
    my $logfile = $logdir . "NCBI_FTP.log";
    `mkdir $logdir` unless -d $logdir;
    die "The local directory doesn't exist, please create it first\n"
      unless ( -e $download_dir );

    #check if 32 bit or 64 bit
    my $ascp_dir;
    if($Config{archname} =~ /x86_64/){
	$ascp_dir='aspera_64';
    }else{
	$ascp_dir='aspera_32';
    }
    #s parameters: turn on mirroring; no host directory;
    # non-verbose; exclude .val files; .listing file kept;
    if ( $parameters eq '' ) {
	$parameters = "$path/".$ascp_dir."/connect/bin/ascp -QT -l 50M -k2 -L $logdir -i ".$path.'/'.$ascp_dir."/connect/etc/asperaweb_id_dsa.putty ". 'anonftp@ftp-private.ncbi.nlm.nih.gov:/';
    }

    #Create the log file if it doesn't exist already
    &createfile($logfile) unless ( -e $logfile );
    foreach(@file_types){
	my $remotefile='all.'.$_.'.tar.gz';
	&runascp( $parameters, $remotedir, $remotefile,$download_dir );
    }
    if ($get_gprj) { &get_genomeprojfiles($download_dir); }
    

}

sub runascp{
    my ( $parameters, $remotedir,$remotefile,$localdir ) = @_;
    my $status = 1;
    my $count  = 0;
    while ( $status != 0 && $count < 10 ) {
    	my $ascp_cmd = $parameters.$remotedir.$remotefile. " $localdir";
	$logger->info("Downloading file: $remotefile");
	$logger->debug($ascp_cmd);
	$status = system($ascp_cmd);

	if($status){
	    $logger->warn("Problem with downloading file: $remotefile".". Waiting 60 seconds before attempting again.");
	    sleep 60;
	}
        $count++;
    }

    if($status){
	$logger->fatal("Could not download file: $remotefile".", after $count attempts!");
	die;
    }
}
    

sub NCBIftp_wget3 {
    my $localdir= shift;
	
    my $host       = 'ftp://ftp.ncbi.nih.gov';
    my $remotedir  = 'genomes/Bacteria/all.*';
    my $parameters = '';
    my $overwrite  = 0;                                   #default is not to overwrite
    my $get_gprj = 1;    #default is to get the organism info and complete genome files
    my $logdir = $localdir . '/log/';
    my $logfile = $logdir . "NCBI_FTP.log";
    `mkdir $logdir` unless -d $logdir;

    $logger->fatal("The local directory doesn't exist, please create it first\n")
      unless ( -e $localdir );
    die "The local directory doesn't exist, please create it first\n"
      unless ( -e $localdir );

    #s parameters: turn on mirroring; no host directory;
    # non-verbose; exclude .val files; .listing file kept;
    if ( $parameters eq '' ) {
        $parameters = "--passive-ftp -P $localdir -m -nH --cut-dirs=2 -w 2 -nv -K -R val -a $logfile ";
    }

    #Create the log file if it doesn't exist already
    &createfile($logfile) unless ( -e $logfile );

    #if the output dir exists, put a warning in log and overwrite if asked
    if ( -e $localdir ) {
        if ($overwrite) {
	    $logger->warn("Directory $localdir already exists, files is being overwritten\n");
            &runwget;
            if ($get_gprj) { &get_genomeprojfiles; }
        } else {
	    $logger->error("Update failed on $localdir because directory already exists \n");
        }
    } else {
        &runwget( $parameters, $host, $remotedir );
        if ($get_gprj) { &get_genomeprojfiles($localdir); }
    }

    #return the directory that contains the newly downloaded genomes from NCBI
    return $localdir;
}


#the simple subroutine that makes a system call to wget
# see http://www.gnu.org/software/wget/manual/wget.html for wget manual
sub runwget {
    my ( $parameters, $host, $remotedir ) = @_;
    my $status = 1;
    my $count  = 0;
    while ( $status != 0 && $count < 5 ) {
    	my $wget_cmd = "wget $parameters $host/$remotedir";
        $status = system($wget_cmd);
        sleep 120 unless $status == 0;
        $count++;
    }
}

sub get_genomeprojfiles {
    my ($localdir) = @_;

    my $ncbi_orginfo_url='http://www.ncbi.nih.gov/genomes/lproks.cgi?view=0&dump=selected';
    my $ncbi_orginfo_file=$localdir."/NCBI_orginfo.txt";

    $logger->info("Downloading file: $ncbi_orginfo_file from NCBI at: $ncbi_orginfo_url");

    my $ncbi_orginfo_content    = get($ncbi_orginfo_url);
    open( my $ORGINFO,'>', $ncbi_orginfo_file ) or die "Can't create file $ncbi_orginfo_file";
    print $ORGINFO $ncbi_orginfo_content;
    close $ORGINFO;

    my $ncbi_compgen_url='http://www.ncbi.nih.gov/genomes/lproks.cgi?view=1&dump=selected';
    my $ncbi_compgen_file=$localdir."/NCBI_completegenomes.txt";

    $logger->info("Downloading file: $ncbi_compgen_file from NCBI at: $ncbi_compgen_url";

    my $ncbi_compgen_content   = get($ncbi_compgen_url);
    open( my $COMPGEN, '>',$ncbi_compgen_file ) or die "can't create file $ncbi_compgen_file";
    print $COMPGEN $ncbi_compgen_content;
    close $COMPGEN;
}

sub writetolog {
    my ( $message, $logfile ) = @_;
    open( LOG, ">>$logfile" ) or die "can not open log file $logfile\n";
    print LOG $message;
    close LOG;
}

sub createfile {
    my $filename     = shift;
    my $createstatus = system("touch $filename");
    if ( $createstatus == 0 ) { chmod 0666, $filename; }
    else { writetolog("File $filename cannot be created\n"); }
}
