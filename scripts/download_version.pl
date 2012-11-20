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

#Specify valid file types for download
my @valid_file_types=qw/GeneMark Glimmer3 Prodigal asn cog faa ffn fna frn gbk gff ptt rnt rps rpt val/;
#create a hash with valid file types as keys
my %valid_file_type_lookup = map {$_=>1}@valid_file_types;


my ($download_dir,$logger_cfg,$ftp_flag,$draft_flag,$draft_only_flag,$search,@types_of_files,$help);
my $res = GetOptions("directory=s" => \$download_dir,
		     "search=s" =>\$search,
		     "logger=s" => \$logger_cfg,
                     "ftp" => \$ftp_flag,
		     "incomplete"=>\$draft_flag,
		     "only_incomplete"=>\$draft_only_flag,
		     "types_of_files=s"=>\@types_of_files,
		     "help"=> \$help)or pod2usage(2);

pod2usage(-verbose=>2) if $help;

pod2usage($0.': You must specify a download directory.') unless defined $download_dir;

#user can specify multiple file types using a ',' (e.g. -t asn,faa) and/or using multiple -t options (e.g. -t asn -t faa)
@types_of_files = split(/,/,join(',',@types_of_files));

#this contains a list of valid file types we will download (always need gbk type so add it here)
my @file_types= qw/gbk/;
#my @file_types = qw/gbk faa ffn fna frn gff rpt/;
   

#check if user provides additional file types to download
if(@types_of_files){
    foreach my $user_type (@types_of_files){
	#check to make sure it is a valid file type
	if(exists $valid_file_type_lookup{$user_type}){
	    push @file_types, $user_type;
	}else{
	    pod2usage($0.": The file type: \"$user_type\" is not valid with -t option. Use download_version.pl -h to see a list of valid file types.\n");
	}
    }
}


# Find absolute path of script, yes we have to
# do this again because of scope issues
my ($path) = abs_path($0) =~ /^(.+)\//;

# Clean up the download path
$download_dir .= '/' unless $download_dir =~ /\/$/;

# Set the logger config to a default if none is given
$logger_cfg = "logger.conf" unless($logger_cfg);
Log::Log4perl::init($logger_cfg);
my $logger = Log::Log4perl->get_logger;

if($search||$draft_flag||$draft_only_flag){
    $logger->info("Using FTP to download since --search,--incomplete, and/or --only_incomplete option(s) selected.");
    $ftp_flag=1;
}

$logger->logdie("The local directory doesn't exist, please create it first") unless  -e $download_dir ;


$logger->info("Downloading files to directory: $download_dir");

my $logfile = $download_dir . "log.txt";   
#Create the log file if it doesn't exist already
&createfile($logfile) unless ( -e $logfile );

#Get the metadata for the genomes
#&get_genomeprojfiles($download_dir); 

#Have to settle for using old metadata for now (see notes below)
&get_deprecated_metafiles_from_dropbox($download_dir);

if($ftp_flag){    
    #Download all genomes from NCBI using FTP
    $logger->info("Downloading genomes using FTP option");
    $download_dir = NCBIftp_wget3($download_dir);
}else{
    #Download all genomes from NCBI using ASPERA
    $logger->info("Downloading genomes using Aspera option");
    $download_dir = NCBI_aspera($download_dir);
}

sub NCBI_aspera{
    my $download_dir= shift;

    my $remotedir  = 'genomes/Bacteria/';
    
    #check if 32 bit or 64 bit
    my $ascp_dir;
    if($Config{osname} =~/linux/){
	if($Config{archname} =~ /x86_64/){
	    $ascp_dir='aspera_64';
	}else{
	    $ascp_dir='aspera_32';
	}
    }elsif($Config{osname} =~ /darwin/){
	    $ascp_dir='aspera_mac';
	
    }elsif($Config{osname} =~ /MSWin32/){
	$logger->logdie("Looks like you are running Windows. MicrobeDB doesn't run on Windows yet.");      
    }else{
	$logger->logdie("Can't figure out what OS you are using so can't use aspera to download. You can try downloading by FTP instead by using --ftp option.");
    }
  
    my $parameters = "$path/".$ascp_dir."/connect/bin/ascp -QT -l 100M -k2 -L $download_dir -i ".$path.'/'.$ascp_dir."/connect/etc/asperaweb_id_dsa.putty ". 'anonftp@ftp-private.ncbi.nlm.nih.gov:/';
    

    foreach(@file_types){
	my $remotefile='all.'.$_.'.tar.gz';
	&runascp( $parameters, $remotedir, $remotefile,$download_dir );
    }

    

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
	$logger->logdie("Could not download file: $remotefile".", after $count attempts!");
    }
}
    

sub NCBIftp_wget3 {
    my $localdir= shift;
	
    my $host       = 'ftp://ftp.ncbi.nih.gov';
    
    my $wget_parameters = "--passive-ftp -P $localdir -m -nH --cut-dirs=2 -w 2 -nv -K -R val -a $logfile ";
    
    unless($draft_only_flag){
	#Download genomes from RefSeq
	$logger->info("Downloading RefSeq genomes now.");
	if($search){
	    #only download genomes matching users search criteria
	    $logger->debug("Getting list of directories and files from NCBI.");
	    my @file_list=get_ftp_file_list($host.'/genomes/Bacteria/');
	    my @good_dir=grep{/^$search/i}@file_list;
	    $logger->info("Found ".scalar(@good_dir)." RefSeq genomes that matched the search: $search");
	    foreach my $genome_dir (@good_dir){
		$logger->info("Downloading genome: $genome_dir");
		foreach my $file_type (@file_types){
		    my $remotedir = 'genomes/Bacteria/'.$genome_dir.'/*.'.$file_type;	    
		    &runwget( $wget_parameters, $host, $remotedir );
		}
	    }
	}else{
	    foreach my $file_type (@file_types){
		my $remotedir  = 'genomes/Bacteria/all.'.$file_type.'.tar.gz';
		&runwget( $wget_parameters, $host, $remotedir );
	    }	
	}
    }

    
    if($draft_flag|| $draft_only_flag){
	#Download draft genomes
	$logger->info("Downloading draft genomes now.");
	my $root_dir="genomes/Bacteria_DRAFT/";
	$logger->debug("Getting list of directories and files from NCBI draft genomes.");
	my @file_list=get_ftp_file_list($host.'/'.$root_dir);
	my @good_dir;
	if($search){
	    #only download genomes matching users search criteria
	    @good_dir=grep{/^$search/i}@file_list;
	    $logger->info("Found ".scalar(@good_dir)." draft genomes that matched the search: $search");
	}else{
	    @good_dir=@file_list
	}
	foreach my $genome_dir (@good_dir){
	    $logger->info("Downloading genome: $genome_dir");
	    foreach my $file_type (@file_types){
		my $remotedir = $root_dir.$genome_dir.'/*contig.'.$file_type.'.tgz';	    
		&runwget( $wget_parameters, $host, $remotedir );
	    }
	}
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
    my $stdout;
    while ( $status != 0 && $count < 5 ) {
    	my $wget_cmd = "wget $parameters $host/$remotedir";
        $stdout=`$wget_cmd`;
	$status=$? >> 8;
	if($?){
	    $logger->warn("Problem with downloading! Waiting 60 seconds before attempting again.");
	    sleep 60;
	}
        $count++;
    }
    if($status){
	$logger->logdie("Could not complete downloading, after $count attempts!");
    }
    return $stdout;
}

sub get_ftp_file_list{
    my ($ftp_site)=@_;
    
    my $list_cmd="wget --no-remove-listing -a $logfile $ftp_site";
    my $status=system($list_cmd);
    if($status){
        $logger->logdie("Can't get list of files from $ftp_site");
    }
    my $list_file=".listing";
    open(my $LIST,'<',$list_file) || $logger->logdie("Couldn't open the ftp listling file, $list_file, from $ftp_site");
    my @file_list;
    while(<$LIST>){
	chomp;
	my @fields=split;
	push @file_list,$fields[8];
    }
    close($LIST);
    #remove the tmp files created
    unlink ($list_file);
    unlink('index.html');

    return @file_list;

}

#Note this is a temporary fix due to NCBI no longer hosting metadata files (see get_genomeprojfiles() comments below)
sub get_deprecated_metafiles_from_dropbox{
    my ($localdir)=@_;
    
    #http://dl.dropbox.com/u/5329340/NCBI_completegenomes.txt
    #http://dl.dropbox.com/u/5329340/NCBI_orginfo.txt
    my $wget_parameters="-a $logfile --passive-ftp ";
    my $public_dropbox='http://dl.dropbox.com/u/5329340';

    $logger->info("Note: NCBI has removed their metadata files. We are looking for another source of metadata information, but until then we can only use metadata for genomes from before June, 2012.");  

    #get NCBI_orginfo.txt
    my $ncbi_orginfo=$localdir."NCBI_orginfo.txt";
    my $ncbi_orginfo_remote="NCBI_orginfo.txt";
    $logger->info("Downloading file: $ncbi_orginfo from Dropbox at: $public_dropbox/$ncbi_orginfo_remote");  
    runwget($wget_parameters."-O $ncbi_orginfo",$public_dropbox,$ncbi_orginfo_remote);

    #get NCBI_completegenomes.txt
    my $ncbi_complete=$localdir."NCBI_completegenomes.txt";
    my $ncbi_complete_remote="NCBI_completegenomes.txt";
    $logger->info("Downloading file: $ncbi_complete from Dropbox at: $public_dropbox/$ncbi_complete_remote");  
    runwget($wget_parameters."-O $ncbi_complete",$public_dropbox,$ncbi_complete_remote);

}

sub get_genomeprojfiles {
    my ($localdir) = @_;

    #Note1: Currently grabbing data from ftp://ftp.ncbi.nih.gov/genomes/genomeprj/
    #Note2: We used to grab it from http://www.ncbi.nih.gov/genomes/lproks.cgi but NCBI shut this page down. (http://www.ncbi.nlm.nih.gov/About/news/17Nov2011.html)
    #Note3: Supposedly these are going to be phased out and replaced by: ftp://ftp.ncbi.nlm.nih.gov/genomes/GENOME_REPORTS/prokaryotes.txt
    #However, this new file is very limited (does not contain any organism information), and is using the new BioProject Accession (PRJNAXXXX) which is not being well supported by NCBI yet (i.e older genome id is still in directory name and all genbank records).
    #Note4: As of Nov. 15,2012 the metadata files are not available from NCBI ftp site. As temporary solution I have obtained the most recent metadata as of June 2012 and I am hosting these files via Dropbox. Therefore, metadata will only exist for genomes deposited before this date.
    
    my $ncbi_org_dir='ftp://ftp.ncbi.nih.gov/genomes/genomeprj';
    my $wget_parameters="-a $logfile --passive-ftp ";
   
    #get NCBI_orginfo.txt
    my $ncbi_orginfo_remote='lproks_0.txt';
    my $ncbi_orginfo_file=$localdir."NCBI_orginfo.txt";
    $logger->info("Downloading file: $ncbi_orginfo_file from NCBI at: $ncbi_org_dir/$ncbi_orginfo_remote");  
    runwget($wget_parameters."-O $ncbi_orginfo_file",$ncbi_org_dir,$ncbi_orginfo_remote);

    #get NCBI_completegenomes.txt
    my $ncbi_compgen_remote='lproks_1.txt';
    my $ncbi_compgen_file=$localdir."NCBI_completegenomes.txt";
    $logger->info("Downloading file: $ncbi_compgen_file from NCBI at: $ncbi_org_dir/$ncbi_compgen_remote");
    runwget($wget_parameters."-O $ncbi_compgen_file",$ncbi_org_dir,$ncbi_compgen_remote);
    
    #get info about incomplete genomes
    my $ncbi_incompgen_remote='lproks_2.txt';
    $logger->info("Downloading incomplete genome information from NCBI at: $ncbi_org_dir/$ncbi_incompgen_remote");
    my $ncbi_incompgen_content = runwget($wget_parameters."-O -",$ncbi_org_dir,$ncbi_compgen_remote);

    #append the incomplete genome info the completed genome info table file
    $logger->debug("Formatting incomplete genome table to match completed genome table.");
    my $formatted_incompgen_content=format_incomplete_table_to_match_ncbi_complete_table($ncbi_incompgen_content);
    
    $logger->info("Appending information on incomplete genomes to $ncbi_compgen_file");
    open( my $COMPGEN, '>>',$ncbi_compgen_file ) or die "can't create file $ncbi_compgen_file";
    print $COMPGEN $formatted_incompgen_content;
    close $COMPGEN;

}

sub format_incomplete_table_to_match_ncbi_complete_table{
    my $table=shift;
    my @lines=split(/\n/,$table);

    #remove header lines
    shift(@lines);
    shift(@lines);
    
    my @formatted_lines;
    foreach my $line (@lines){
	#Table we want has 15 columns, so pre-fill them here
	my @good_fields=('')x15;

	my @fields=split(/\t/,$line);

	#Map fields from incomplete to complete (need to look at tables manually to figure out indices for arrays)
	@good_fields[0..5]=@fields[0..5];
	@good_fields[6,7]=@fields[11,12];
	$good_fields[10]=$fields[13];
	$good_fields[15]=$fields[14];
	push(@formatted_lines,join("\t",@good_fields));
    }
    return join("\n",@formatted_lines);
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

download_version.pl - Downloads bacteria and archaea genomes from NCBI.

=head1 USAGE

download_version.pl [-s <search> -t <file_type> -i -o -f -l <logger.conf> -h] -d <directory>

Examples:

##Download all RefSeq genomes using Aspera downloader

B<download_version.pl -d /share/genomes/>

##OR Download a subset of RefSeq genomes

B<download_version.pl -d /share/genomes/ -s Pseudomonas>

##OR download a subset of both completed and draft genomes 

B<download_version.pl -d /share/genomes/ -s Escherichia_coli -i>

##OR download additional types of genome files (in addition to .gbk)

B<download_version.pl -d /share/genomes/ -t fna,faa,gff>

=head1 OPTIONS

=over 4

=item B<-d, --directory <dir>>

Directory where genome files will be stored. (MANDATORY)

=item B<-s, --search <name of genome> >

Only download genomes that "match" your search of choice. Search matches from beginning of genome name which is usually the Genus name of the organism. Therefore, "Escherichia" will download all genomes with that Genus or "Escherichia_coli" will download all E.coli strains. "coli" will not match anything. Search is NOT case-sensitive.  

=item B<-i, --incomplete>

In addition to completed (RefSeq) genomes, download all (or a subset if using the -s option) incomplete/draft genomes. 

=item B<-o, --only_incomplete>

Download only incomplete/draft genomes. No complete (RefSeq) genomes will be downloaded.

=item B<-t, --types_of_files <file_type1,file_type2,etc.>>

Download genome data in other file types (in addition to required .gbk files). File types must be delimited with a ','. Valid file types are:

B<GeneMark, Glimmer3, Prodigal, asn, cog, faa, ffn, fna, frn, gbk, gff, ptt, rnt, rps, rpt, val>

=item B<-f, --ftp >

Use FTP download instead of the default Aspera downloader. Note FTP is used if -s, -o, or -i options are used.

=item B<-l, --logger <logger config file>>

Specify an alternative logger.conf file.

=item B<-h, --help>

Displays the entire help documentation.

=back

=head1 DESCRIPTION

B<download_version.pl> This script downloads bacteria and archaea genomes from the NCBI FTP site. Default options will download ALL completed RefSeq genomes using the Aspera downloader. Options are available to also (or only) download incomplete/draft genomes. In addition, a subset of genomes can be downloaded using the --search option, which is useful for testing or for those interested in a particular group of organisms (e.g all "Pseudomonas"). Download time will vary depending on your download speed, the mood of NCBI's FTP server, the selection of different file formats, etc., but expect anywhere from 10 minutes to a few hours. Depending on the options used some files are downloaded in compressed format (tar.gz) and will require the use of B<unpack_version.pl> to expand all files into proper flat file structure where each genome has its own directory.

=head1 AUTHOR

Morgan Langille, E<lt>morgan.g.i.langille@gmail.comE<gt>

=cut

