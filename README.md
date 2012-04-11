MicrobeDB
==

ABOUT
=====
* MicrobeDB provides centralized local storage and access to completed archaeal and bacterial genomes.
* MicrobeDB contains three main features. 

1. All "flat" files associated with the each genome are downloaded from NCBI (http://www.ncbi.nlm.nih.gov/genomes/lproks.cgi) and stored locally in a directory of your choosing.
    
2. For each genome, information about the organism, chromosomes within the organism, and genes within each chromosome are parsed and stored in a MySQL database including sequences and annotations.

3. A Perl API is provided to interface with the MySQL database and allow easy use of the data.

* By default all RefSeq genomes are downloaded
    * Incomplete/draft genomes can also be obtained.
    * A subset of genomes from a particular genera can be obtained instead based on a search term.
    * Unpublished/in-house genomes can be added easily.

* A presentation providing an overview of MicrobeDB is at [information/MicrobeDB_Overview.pdf](http://www.slideshare.net/mlangill/basic-overview-microbedb)

REQUIREMENTS
============
* MySQL
* Perl
* Perl Modules (available from CPAN)
    * BioPerl
    * DBI
    * DBD::mysql
    * Parallel::ForkManager
    * Log::Log4perl
    * Sys::CPU

* ~20GB of hard drive space (this is based on default settings). Much less can be used by downloading a subset of genomes. Much more can be used if incomplete genomes or additional file types are downloaded.

Installing the MicrobeDB software
=================================
* Download MicrobeDB using a Git client or sinply by clicking the ["ZIP" link](https://github.com/mlangill/MicrobeDB/zipball/master) on the top left of the webpage.
* For installation information see [MicrobeDB/information/INSTALL/INSTALL.md](https://github.com/mlangill/MicrobeDB/blob/master/information/INSTALL/INSTALL.md).

Updating the MicrobeDB software
===============================
* To update your MicrobeDB software see [MicrobeDB/information/UPDATE/UPDATE.md](https://github.com/mlangill/MicrobeDB/blob/master/information/UPDATE/UPDATE.md).

Downloading a new "version" of genomes with MicrobeDB
=====================================================
* To use MicrobeDB you will have to download and load a new version of genome files. 
* All programs must be run from the command line and are located in the directory "scripts". Open up a console and change into the scripts directory:

        cd MicrobeDB/scripts

* Now, by default MicrobeDB will download,unpack, parse and load all completed RefSeq genomes. You can do this with the following command (and replace the directory after the -d option with any directory where you want the genome files to be stored.)

        ./download_load_and_delete_old_version.pl -d /your_path/microbedb_genome_storage

* ./download_load_and_delete_old_version.pl is a basically a wrapper script that runs 3 other scripts. It is conveniant because it does everything for you and can be easily set to run on a regular basis (monthly, bimonthly, etc.) as a "cron" job or with other scheduling software.

* You can run the 3 scripts manually, which gives you more control and maybe useful in case there are any errors in the update. 

1. download_version.pl
2. unpack_version.pl
3. load_version.pl

* You can use the -h option (e.g. ./download_version.pl -h) or 'perldoc download_version.pl' to get help for any of the scripts.
* For example if you want to download incomplete genomes as well you can specify this with the -i option.

        ./download_version.pl -d /your_path/ -i

* If you wanted to download all E.coli strains (complete or incomplete) you can use the -s option.

        ./download_version.pl -d /your_path/ -i -s Escherichia_coli

* If you wanted to download other file formats for the genome beyond the required .gbk file then you can specify them with the -t option (seperated by commas)
       
        ./download_version.pl -d /your_path/ -t faa,fna,gff

* You can specify any of the download_version.pl options in the download_load_and_delete_old_version.pl script using the -s with single quotes.

        ./download_load_and_delete_old_version.pl -d /your_path/ -s '-i -s Escherichia_coli -t faa,fna'

Using multiple processors
-------------------------
* If your computer has multiple processors, MicrobeDB can use these to increase the speed of unpacking and loading the genomes into MicrobeDB. 

* This is speficied using the '-p' option. Using it by itself with use all available processors on your computer. You can also limit the number of processors by specifying it after the option. 

        ./download_load_and_delete_old_version.pl -d /your_path/ -p 2

Overview of MicrobeDB
=====================
* Genome/Flat files are stored in one central location

* Information at the genome project, chromosome, and gene level are parsed and stored in a MySQL database including sequences and annotations 

* The files and the database can be updated easily via a single script

* The genome files are stored in consistent structure with many different file types:

    * Bacteria_2009-09-01
        * Acaryochloris_marina_MBIC11017
        * Acholeplasma_laidlawii_PG_8A
        * Acidimicrobium_ferrooxidans_DSM_10331
        * Acidiphilium_cryptum_JF-5
            * NC_009467.asn
            * NC_009467.faa
            * NC_009467.ffn
            * NC_009467.fna
            * NC_009467.gbk
            * etc.

* The MySQL database contains the following 4 main tables:

    * Version
        * Each monthly download from NCBI is given a new version number
        * Data will not change if you always use the same version number of microbedb
        * Version date can be cited for any method publications
        * Each version contains one or more Genomeprojects (genomes)

    * Genomeproject
        * Contains information about the genome project and the organism that was sequenced
        * E.g. taxon_id, org_name, lineage, gram_stain, genome_gc, patho_status, disease, genome_size, pathogenic_in, temp_range, habitat, shape, arrangement, endospore, motility, salinity, etc.
        * Each genomeproject contains one or more Replicons

    * Replicon
        * Chromosome, plasmids, or contigs (for incomplete genomes)
        * E.g. rep_accnum, definition, rep_type, rep_ginum, cds_num, gene_num, protein_num, genome_id, rep_size, rna_num, rep_seq (complete nucleotide sequence)
        * Each replicon contains one or more genes

    * Gene
        * Contains gene annotations and also the DNA and protein sequences (if protein coding gene)
        * E.g. gid, pid, protein_accnum, gene_type, gene_start, gene_end, gene_length, gene_strand, gene_name, locus_tag, gene_product, gene_seq, protein_seq

Using MicrobeDB
==============
* Once MicrobeDB is installed and you have downloaded your first version of genomes you are ready to start using MicrobeDB. 
* Since MicrobeDB parses genomes in a MySQL database you can search and retrieve information in various ways. 

Searching with MySQL
--------------------
* If you are familiar with MySQL syntax and are comfortable with a commandline then you can use the traditional MySQL client:
    
1. Connecting directly to MySQL database via command line client

        mysql -u microbedb -p

2. Then use MySQL syntax to do your queries. For example:
	
        #get a list of all genomes that are described as pathogens
		select * from genomeproject where patho_status = 'pathogen'
		
		#get all genes with name "dnaA"
		select * from gene where gene_name='dnaA'
		
Installing 3rd party MySQL programs
-----------------------------------
* If you are not as familiar with MySQL syntax and would like a more pretty interface, then you can use other software to query MicrobeDB.
		

1. Using a client desktop application such as [MySQL Workbench](http://www.mysql.com/products/workbench/)
	* This is a simple to install and free software package provides many features which make querying MySQL databases easier.
	
2. Using a web based application such as [phpMyAdmin](http://www.phpmyadmin.net/home_page/index.php)
    * phpMyAdmin is more difficult to install, but once it is it allows a web-based method to search and interact with your database.


Programming with the MicrobeDB API
----------------------------------
* If you know how to program in Perl you can use the MicrobeDB Perl API which allows you to retrieve data without constructing MySQL queries.
* Example of a simple perl script using the MicrobeDB API that searches for all 'recA' genes and prints them in 'Fasta' format:
	
	    #Import the MicrobeDB API
		use lib '/your/path/to/MicrobeDB';
		use MicrobeDB::Search;
	
	    #intialize the search object
		$search_obj= MicrobeDB::Search();
	
	    #create the object that has properties that must match in the database
		$gene_obj= MicrobeDB::Gene(gene_name => 'recA');
		
		#do the actual search
		@genes = $search_obj->object_search($gene_obj);
		
		#loop through each gene we found and print in FASTA format
		foreach my $gene (@genes){
		print'>',$gene->gid(),"\n",$gene->gene_seq(),"\n";
		}	

* See more examples using the MicrobeDB API in [information/example_scripts] (https://github.com/mlangill/MicrobeDB/tree/master/information/example_scripts/).


Extending MicrobeDB
===================
* MicrobeDB can be extended to include additional types of custom information
* The best way to extend MicrobeDB is to create your own tables with the fields of your choice and use a stable NCBI based identifier to "link" the tables. The reason to use these types of ids instead of the primary MicrobeDB ids is that the NCBI ids will remain the same between MicrobeDB versions. Use the following fields:
    * To extend a Genomeproject, use the field "gp_id"
    * To extend a Replicon, use the field "rep_accnum" 
    * To extend a Gene, use the field "gid" or "pid"

* For example, imagine you wanted to store SNP data. You want to store the position of the SNP, an in-house experiment id, and the base at that position. Then you would want to create a new table and use the rep_accnum field to join the MicrobeDB replicon table to your in-house table. Your columns would be "your_primary_snp_id", "rep_accnum", "your_experiment_id", "snp_position", "snp_base".  

Questions/Comments
==================
* Contact: Morgan Langille
* Email: morgan.g.i.langille@gmail.com
