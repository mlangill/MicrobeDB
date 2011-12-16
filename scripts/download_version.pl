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

#All genomes are downloaded from NCBI using either Aspera (default) or FTP
#Aspera should be much faster, but if you have problems you might want to try using FTP (download_version.pl --ftp <DIR>)

use strict;
use warnings;
use Time::localtime;
use Time::Local;
use File::stat;
use Getopt::Long;
use Log::Log4perl;
use Pod::Usage;
use LWP::Simple;
use Config;
use Cwd qw(abs_path getcwd);

BEGIN{
# Find absolute path of script
my ($path) = abs_path($0) =~ /^(.+)\//;
chdir($path);
};

my ($download_dir,$logger_cfg,$ftp_flag,$help);
my $res = GetOptions("directory=s" => \$download_dir,
		     "logger=s" => \$logger_cfg,
                     "ftp" => \$ftp_flag,
		     "help"=> \$help)or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify a download directory.') unless defined $download_dir;

# Find absolute path of script, yes we have to
# do this again because of scope issues
my ($path) = abs_path($0) =~ /^(.+)\//;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

if($ftp_flag){    
    #Download all genomes from NCBI using FTP
    $logger->info("Downloading files using FTP option");
    $download_dir = NCBIftp_wget3($download_dir);
}else{
    #Download all genomes from NCBI using ASPERA
    $logger->info("Downloading files using Aspera option");
    $download_dir = NCBI_aspera($download_dir);
}

#get_genomeprojfiles($dir);
$logger->info("Using $download_dir");

sub NCBI_aspera{
    my $download_dir= shift;
	
    my $remotedir  = 'genomes/Bacteria/';
    #all file types
    #my @file_types = qw/GeneMark Glimmer3 Prodigal asn cog faa ffn fna frn gbk gff ptt rnt rps rpt val/;
    
    #File types required by MicrobeDB
    #my @file_types = qw/gbk/;
    
    #Default file types downloaded
    my @file_types = qw/gbk faa ffn fna frn gff rpt/;
    
    my $parameters = '';
    my $overwrite  = 0;                                   #default is not to overwrite
    my $get_gprj = 1;    #default is to get the organism info and complete genome files
    my $logdir = $download_dir . 'log/';
    my $logfile = $logdir . "NCBI_FTP.log";
    `mkdir -p $logdir` unless -d $logdir;
    $logger->logdie("The local directory doesn't exist, please create it first") unless  -e $download_dir ;

    #check if 32 bit or 64 bit
    my $ascp_dir;
    if($Config{osname} =~/linux/){
	if($Config{archname} =~ /x86_64/){
	    $ascp_dir='aspera_64';
	}else{
	    $ascp_dir='aspera_32';
	}
    }elsif($Config{osname} =~ /darwin/){
	if($Config{archname} =~ /x86_64/){
	    $ascp_dir='aspera_mac_64';
	}else{
	    $ascp_dir='aspera_mac_32';
	}
    }elsif($Config{osname} =~ /MSWin32/){
	$logger->logdie("Looks like you are running Windows. MicrobeDB doesn't run on Windows yet.");      
    }else{
	$logger->logdie("Can't figure out what OS you are using so can't use aspera to download. You can try downloading by FTP instead by using --ftp option.");
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

    $logger->info("Downloading file: $ncbi_compgen_file from NCBI at: $ncbi_compgen_url");

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


__END__

=head1 Name

download_version.pl - Downloads all RefSeq bacteria and archaea genomes from NCBI.

=head1 USAGE

download_version.pl [-f -l <logger.conf> -h] -d <directory>

E.g.

#using aspera downloader
download_version.pl -d /share/genomes/

#using traditional ftp downloader
download_version.pl -f -d /share/genomes/

=head1 OPTIONS

=over 4

=item B<-f, --ftp >

Use FTP download instead of aspera downloader.

=item B<-d, --directory <dir>>

Directory where genome files will be stored.

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<download_version.pl> This script downloads all RefSeq bacteria and archaea genomes from the NCBI FTP site. Download time will vary depending on your download speed and the mood of NCBI's FTP server, but expect at least a few hours. Files are downloaded in compressed format (tar.gz). Use unpack_version.pl to expand all files into proper flat file structure where each genome has its own directory.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

