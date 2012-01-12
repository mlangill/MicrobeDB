MicrobeDB
=
##ABOUT##
* MicrobeDB provides centralized local storage and access to completed archaeal and bacterial genomes.

* MicrobeDB contains three main features. 

    1. All "flat" files associated with the each genome are downloaded from NCBI (http://www.ncbi.nlm.nih.gov/genomes/lproks.cgi) and stored locally in a directory of your choosing.

    2. For each genome, information about the organism, chromosomes within the organism, and genes within each chromosome are parsed and stored in a MySQL database including sequences and annotations.

    3. A Perl API is provided to interface with the MySQL database and allow easy use of the data.

* A presentation providing an overview of MicrobeDB is at [information/MicrobeDB_Overview.pdf](http://www.slideshare.net/mlangill/basic-overview-microbedb)

##REQUIREMENTS##
* MySQL
* Perl
* Perl Modules (available from CPAN)
    * BioPerl
    * DBI
    * DBD::mysql
    * Parallel::ForkManager
    * Log::Log4perl
    * Sys::CPU

##INSTALL##
* For installation information see [information/INSTALL/INSTALL.md](https://github.com/mlangill/MicrobeDB/blob/master/information/INSTALL/INSTALL.md).

##Updating##
* To update your MicrobeDB software see [information/UPDATE/UPDATE.md](https://github.com/mlangill/MicrobeDB/blob/master/information/UPDATE/UPDATE.md).

##Usage##
Once MicrobeDB is installed you can connect to the MySQL database using any traditional MySQL method:

1. Connecting directly to MySQL database via command line client

        mysql -u microbedb -p

2. Using a client desktop application such as [MySQL Workbench](http://www.mysql.com/products/workbench/)

3. Using a web based application such as [phpMyAdmin](http://www.phpmyadmin.net/home_page/index.php)

4. Using the MicrobeDB Perl API (no SQL needed!)

    * At the start of your perl script you need:

            use lib '/your/path/to/MicrobeDB';
            
            use MicrobeDB::Search;

    * See examples using the MicrobeDB API in [information/example_scripts] (https://github.com/mlangill/MicrobeDB/tree/master/information/example_scripts/).


##Overview of MicrobeDB##

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


##Questions/Comments##
* Contact: Morgan Langille
* Email: morgan.g.i.langille@gmail.com