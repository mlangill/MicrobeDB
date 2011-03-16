MicrobeDB ChangeLog
=
##v0.2

*Parsing of files is all done within new Parse.pm module (a proper OO module that follows the rest of the MicrobeDB code). Will's old NCBI2hash.pm module is gone. Also, the parsing has been simplified so that everything comes from Genbank files and the two NCBI special table files. This will make maintaining the parsing code more robust and much easier to update.

*Users can now easily add their own non-published genomes. They just put their genbank files for each genome in a directory and load them using the --custom option. The only fields not filled are the information about the organism such as gram stain, pathogenicity, habitat, etc. Things like GC% and size of genome are calculated from the genbank files. Also, taxon information is retrieved for these custom genomes if a taxon id is given in the genbank file. This is a nice feature since many labs have their own unpublished genomes, and is the main reason I started changing microbedb since I have a comparative genomics project that I wanted MicrobeDB to help me organize.

*Somewhat related to the custom genomes, is that I have added rep_type='contig' (just plasmid and chromosome were allowed before). This allows unfinished genomes to be added to MicrobeDB. Also, I added fields to the GenomeProject table class for number of chromosomes, plasmids and contigs. Use "information/INSTALL/update_microbedb.sql" to update your MySQL schema.

*Unpacking of genomes and loading of genomes can be parallelized by giving the -p option (using option by itself it will detect number of cpus and uses all of them, if given number with option it limits itself to that many). This makes the whole update process much faster. User is now required to have perl modules: __Parallel::ForkManager and Sys::CPU installed__.

*Parsing will work on gzipped genbank files. Is a nice feature if disk space is an issue or in the future when number of genomes gets more unbearable.

*In theory parsing would work on embl files as well (since I am using bioperl), but this has not been tested.

*Scripts in the 'scripts/' directory have been updated to use proper options. Also, scripts have been added to allow manipulation at the 'genomeproject' level and not just for entire versions (e.g. load_genome.pl, delete_genome.pl, and reload_genome.pl). This makes adding custom genomes easier as well as fixing 'problematic' genomes from NCBI without having to re-load entire versions.

##v0.1

*Matthew started using logging (Log::Log4perl now required) and I embraced this by adding logging in more places. Also, logging is output to screen at the 'info' level and above, while logging for all categories ('debug' and up) is output to a log file.

*Aspera is used for download by default instead of FTP, allowing faster downloads.
