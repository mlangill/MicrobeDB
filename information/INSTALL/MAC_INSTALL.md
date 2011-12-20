MAC_INSTALL
=
These are installation instructions specific for Mac users.

###Install MySQL (if not already)###
1. Visit http://www.mysql.com/downloads/mysql/ and download appropriate package.
2. Install both the MySQL-your_version.pkg and MySQL StartupItem.pkg (so the mysql server starts every time the computer starts). 
3. Start the MySQL server by restarting your computer or running the following command from a shell:

        sudo /Library/StartupItems/MySQLCOM/MySQLCOM start

4. Add the "mysql" command to your "Path". From a shell type:
    
        sudo pico /etc/paths

    * Then add the following line to the end of the file:
        /usr/local/mysql/bin

    * Save the file.

###Change the MySQL system setting 'max_allowed_packet'###

1. Copy a config file into the proper location
        sudo cp /usr/local/mysql/support-files/my-large.cnf /etc/my.cnf

2. Open up an editor on the config file
        sudo pico /etc/my.cnf

    * Find and change the following line in the config file:

        * From:
                max_allowed_packet = 1M

        * To:
                max_allowed_packet = 64M

3. Restart the MySQL server:
        sudo /Library/StartupItems/MySQLCOM/MySQLCOM restart

###Continue with normal installation###
* Follow steps outlined in the general [INSTALL](/INSTALL)

 