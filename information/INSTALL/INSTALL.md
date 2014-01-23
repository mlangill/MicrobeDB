INSTALL MicrobeDB
=
These are the basic guidelines to getting MicrobeDB set up locally on your machine

##Requirements##
You will need to install the following software BEFORE proceeding with the MicrobeDB installation below. 

* MySQL (see below)
* Perl
* Perl Modules (available from CPAN)
    * BioPerl
    * DBI
    * DBD::mysql
    * Parallel::ForkManager
    * Log::Log4perl
    * Sys::CPU

##Install MySQL##

####MAC OSX: Install MySQL####
1. Visit http://www.mysql.com/downloads/mysql/ and download appropriate package (*.dmg version is recommended).

2. Install both the MySQL-your_version.pkg and MySQL StartupItem.pkg (so the mysql server starts every time the computer starts). 

3. Start the MySQL server by restarting your computer or running the following command from a shell:

        sudo /Library/StartupItems/MySQLCOM/MySQLCOM start

4. Add the "mysql" command to your "Path". From a shell type:
    
        sudo pico /etc/paths

Then add the following line to the end of the file:

        /usr/local/mysql/bin

Save the file.

####MAC OSX: Change the MySQL system settings####

1. Copy a config file into the proper location (could be called **my-default.cnf**)

        sudo cp /usr/local/mysql/support-files/my-large.cnf /etc/my.cnf

2. Open up an editor on the config file

        sudo pico /etc/my.cnf

* Find and change the following line in the config file:
    * From:

                max_allowed_packet = 1M

* To:

                max_allowed_packet = 64M

* Also remove MySQL "strict" mode:
    * From:

	           sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

* To:

               sql_mode=NO_ENGINE_SUBSTITUTION

3. Delete the file at /usr/local/mysql/my.cnf if it exists:

        sudo rm /usr/local/mysql/my.cnf

4. Restart the MySQL server:

        sudo /Library/StartupItems/MySQLCOM/MySQLCOM restart

5. Skip to "Setup MicrobeDB database"

####Ubuntu: Install MySQL####
* Follow directions here: https://help.ubuntu.com/11.10/serverguide/C/mysql.html

####Ubuntu: Change the MySQL system settings####

* Edit the MySQL configuration file 'my.cnf' usually located at /etc/mysql/my.cnf 

* Find 'max_allowed_packet' and change the line to this:

         max_allowed_packet  = 64M

* Remove MySQL "strict" mode:
    * From:

	           sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

* To:

               sql_mode=NO_ENGINE_SUBSTITUTION

* Restart the MySQL server 
  
         sudo /etc/init.d/mysql restart

##Install Perl dependencies#

* MicrobeDB has several Perl dependicies that must be installed for MicrobeDB to function properly.

* Most modules can be installed easily with CPAN (DBI, DBD::mysql, Parallel::ForkManager, Log::Log4perl, Sys::CPU)
    
	     sudo cpan Parallel::ForkManager Log::Log4perl Sys::CPU DBI DBD::mysql
	
    * MAC OS NOTE: We have found that DBD::mysql often does not install properly. The following command seems like the best current fix:

             sudo ln -s /usr/local/mysql/lib/libmysqlclient.18.dylib /usr/lib/libmysqlclient.18.dylib
	
* BioPerl can be installed with CPAN, but we have found that installation is faster by following the directions [here](http://www.bioperl.org/wiki/Installing_Bioperl_for_Unix#INSTALLING_BIOPERL_THE_EASY_WAY_USING_Build.PL).

##Obtain MicrobeDB Software##

* If you have 'git' installed on your system you can simply type the command (this allows easier updating):
         
         git clone https://github.com/mlangill/MicrobeDB.git

OR

* Simply download the code by clicking on the "ZIP" at the top left of the webpage (http://github.com/mlangill/MicrobeDB). Extract the contents and rename the top directory from "mlangill-MicrobeDB-NNNNN" to "MicrobeDB".

* Place the MicrobeDB directory somewhere permanent (possibly where you have other PERL modules installed).

##Setup MicrobeDB database##
Note: Depending on how you have MySQL installed, you may not need to provide a password for the "root" account. If no password is needed then just remove the "-p" from the following statements.  

1. Create a user to access the database (Note: we use the username 'microbedb', but this can be any username).

        mysql -u root -p -e "CREATE USER 'microbedb'@'localhost' IDENTIFIED BY 'some_password'"

2. Give the user access to the microbedb database

        mysql -u root -p -e "GRANT ALL PRIVILEGES ON microbedb.* to 'microbedb'@'localhost'"

2. Create the microbedb database

        mysql -u root -p -e "CREATE DATABASE microbedb"

3. Load the microbedb table structures located at "MicrobeDB/information/INSTALL/microbedb_schema.sql"

        mysql -u root -p microbedb < MicrobeDB/information/INSTALL/microbedb_schema.sql

4. Create or confirm your MySQL login config file ~/.my.cnf

        emacs $HOME/.my.cnf

        [client]

        host=localhost

        user=microbedb (or whatever username you use)

        password=some_password

5. Protect your MySQL config file

        chmod 600 $HOME/.my.cnf

6. Add MicrobeDB to your perl PATH. You can do this by putting the MicrobeDB folder in the same location as your other Perl modules or by adding the path of MicrobeDB to your $PERL5LIB environment variable:
        
        #For Bash shell 
        echo 'export PERL5LIB=/your_path/containing_MicrobeDB/:$PERL5LIB' | cat >> ~/.bashrc

        OR

        #For tsch shell
        echo 'setenv PERL5LIB /your_path/containing_MicrobeDB/:$PERL5LIB' | cat >> ~/.tschrc

That is it! MicrobeDB is now installed on your computer.


### Loading non-NCBI genomes (optional) ###
* Each of your personal genomes should have it's own directory named according to the name of the species. 

* Each genome directory must contain at least 1 genbank file (.gbk). 

* Multiple contigs/chromosomes will be loaded if there are seperate entries in the same genbank file or if there are multiple genbank files in the same directory. 

* You should place all of your genome directories into a single directory (e.g. 'my_unpublished_genomes')

* To save storage space your files may be gzipped (e.g. MicrobeDB will load/read directly from gzipped files). 

* These genomes are loaded using ./load_version.pl with the --custom option. These genomes are always given version id '0' and will never be automatically deleted on updates. 

* For example your file structure should look like this:

    * unpublished_genomes
        * Pseudomonas_aeruginosa_LESB58
            * Pseudomonas_aeruginoas_LESB58.gbk
        * another_genome_name
            * another_genome_name.gbk
            * another_genome_name_plasmid.gbk
        * yet_another_genome
            * yet_another_genome.gbk.gz

* To load all of these genomes at once:
  
        ./scripts/load_version.pl --custom -d /your_absolute_path/unpublished_genomes

* You can add a single genome later with:

        ./scripts/load_genome.pl -d /your_absolute_path/unpublished_genomes/still_yet_another_genome

##Questions/Comments##
* Contact: Morgan Langille
* Email: morgan.g.i.langille@gmail.com
