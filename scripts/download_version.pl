#!/usr/bin/perl
#All genomes are downloaded from NCBI using wget

use strict;
use warnings;
use Time::localtime;
use Time::Local;
use File::stat;
use Getopt::Long;
use LWP::Simple;
use Config;
use Cwd;
#Please update the following variables
my $dir = $ARGV[0];


#Download all genomes from NCBI
my $download_dir = NCBI_aspera($dir);

#get_genomeprojfiles($dir);
print $download_dir;

sub NCBI_aspera{
    my $download_parent_dir= shift;
	
    my $cur_time = localtime;
    my ( $DAY, $MONTH, $YEAR ) = ( $cur_time->mday, $cur_time->mon + 1, $cur_time->year + 1900 );
    if ( $DAY < 10 )   { $DAY   = '0' . $DAY; }
    if ( $MONTH < 10 ) { $MONTH = '0' . $MONTH; }

    my $remotedir  = 'genomes/Bacteria/';
    my $parentdir  = "$download_parent_dir";
    my $prefix     = 'Bacteria';
    my @file_types = qw/GeneMark Glimmer3 Prodigal asn cog faa ffn fna frn gbk gff ptt rnt rps rpt val/;
    my $parameters = '';
    my $clean      = 0;                                   #default is not to clean older directories
    my $overwrite  = 0;                                   #default is not to overwrite
    my $get_gprj = 1;    #default is to get the organism info and complete genome files
    my $logdir = $parentdir . 'log/';
    my $logfile = $logdir . "NCBI_FTP.log";
    `mkdir $logdir` unless -d $logdir;
    die "The local parent directory doesn't exist, please create it first\n"
      unless ( -e $parentdir );
    my $localdir = $parentdir . "$prefix\_$YEAR\-$MONTH\-$DAY";
    `mkdir $localdir` unless -d $localdir;

    #check if 32 bit or 64 bit
    my $ascp_dir;
    if($Config{archname} =~ /x86_64/){
	$ascp_dir='aspera_64';
    }else{
	$ascp_dir='aspera_32';
    }
    my $cwd = cwd();
    #s parameters: turn on mirroring; no host directory;
    # non-verbose; exclude .val files; .listing file kept;
    if ( $parameters eq '' ) {
	$parameters = './'.$ascp_dir."/connect/bin/ascp -QT -l 50M -k2 -L $logdir -i ".$cwd.'/'.$ascp_dir."/connect/etc/asperaweb_id_dsa.putty ". 'anonftp@ftp-private.ncbi.nlm.nih.gov:/';
    }

    #Create the log file if it doesn't exist already
    &createfile($logfile) unless ( -e $logfile );
    foreach(@file_types){
	my $remotefile='all.'.$_.'.tar.gz';
	&runascp( $parameters, $remotedir, $remotefile,$localdir );
    }
    if ($get_gprj) { &get_genomeprojfiles($localdir); }
    

    #create a sym link from Bacteria to the new directory
    unlink "$parentdir$prefix" if ( -l "$parentdir$prefix" );
    symlink "$localdir", "$parentdir$prefix"
      or &writetolog("Unable to create symlink from $localdir to $parentdir$prefix\n");

    if ($clean) {
        &cleandirectory( $cur_time, $parentdir );
    }

    #return the directory that contains the newly downloaded genomes from NCBI
    return $localdir;
}

sub runascp{
    my ( $parameters, $remotedir,$remotefile,$localdir ) = @_;
    my $status = 1;
    my $count  = 0;
    while ( $status != 0 && $count < 5 ) {
    	my $ascp_cmd = $parameters.$remotedir.$remotefile. " $localdir";
	print $ascp_cmd;
	$status = system($ascp_cmd);

        sleep 120 unless $status == 0;
        $count++;
    
    }
}
    

sub NCBIftp_wget3 {
    my $download_parent_dir= shift;
	
    my $cur_time = localtime;
    my ( $DAY, $MONTH, $YEAR ) = ( $cur_time->mday, $cur_time->mon + 1, $cur_time->year + 1900 );
    if ( $DAY < 10 )   { $DAY   = '0' . $DAY; }
    if ( $MONTH < 10 ) { $MONTH = '0' . $MONTH; }

    my $host       = 'ftp://ftp.ncbi.nih.gov';
    my $remotedir  = 'genomes/Bacteria/all.*';
    my $parentdir  = "$download_parent_dir";
    my $prefix     = 'Bacteria';
    my $parameters = '';
    my $clean      = 0;                                   #default is not to clean older directories
    my $overwrite  = 0;                                   #default is not to overwrite
    my $get_gprj = 1;    #default is to get the organism info and complete genome files
    my $logdir = $parentdir . 'log/';
    my $logfile = $logdir . "NCBI_FTP.log";
    `mkdir $logdir` unless -d $logdir;

    die "The local parent directory doesn't exist, please create it first\n"
      unless ( -e $parentdir );
    my $localdir = $parentdir . "$prefix\_$YEAR\-$MONTH\-$DAY";

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
            &writetolog( "Directory $localdir already exists, files is being overwritten\n",
                $logfile );
            &runwget;
            if ($get_gprj) { &get_genomeprojfiles; }
        } else {
            &writetolog( "Update failed on $YEAR-$MONTH-$DAY because directory already exists \n",
                $logfile );
        }
    } else {
        &runwget( $parameters, $host, $remotedir );
        if ($get_gprj) { &get_genomeprojfiles($localdir); }
    }

    #create a sym link from Bacteria to the new directory
    unlink "$parentdir$prefix" if ( -l "$parentdir$prefix" );
    symlink "$localdir", "$parentdir$prefix"
      or &writetolog("Unable to create symlink from $localdir to $parentdir$prefix\n");

    if ($clean) {
        &cleandirectory( $cur_time, $parentdir );
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
    my $content    = get('http://www.ncbi.nih.gov/genomes/lproks.cgi?view=0&dump=selected');
    my $content2   = get('http://www.ncbi.nih.gov/genomes/lproks.cgi?view=1&dump=selected');
    open( ORGINFO, ">$localdir/NCBI_orginfo.txt" )
      or die "can't create file $localdir/NCBI_orginfo.txt";
    open( COMPGEN, ">$localdir/NCBI_completegenomes.txt" )
      or die "can't create file $localdir/NCBI_completegenomes.txt";
    print ORGINFO $content;
    print COMPGEN $content2;
    close ORGINFO;
    close COMPGEN;
}

#delete backup directories that are older than 90 days
sub cleandirectory {
    my $curdate = shift;
    my $dir     = shift;
    opendir( DIR, $dir );
    my $file;
    while ( defined( $file = readdir(DIR) ) ) {
        next if $file =~ /^\.\.?$/;
        if ( -d $file ) {
            my $filestat        = stat($file);
            my $filechangeinode = $filestat->ctime;
            my $filechangedate  = localtime($filechangeinode);

            #90 days has 7776000 seconds
            if ( $curdate - $filechangedate > 7776000 ) {
                system("rm -rf $file");
            }
        }
    }
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
