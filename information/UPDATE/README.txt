Updating MicrobeDB
=
###How to update MicrobeDB###

####Step 1: Update the MicrobeDB code####
The MicrobeDB software will probably need to be updated every once in awhile. Bugs will be found and features will be added over time. 

Updating MicrobeDB is straight-forward. If you originally installed MicrobeDB via Git. 
Then you can update the code easily using git:

"git pull"

If you downloaded MicrobeDB from GitHub manually then download the MicrobeDB package again and replace the old MicrobeDB directory with the new one:

http://github.com/mlangill/MicrobeDB

####Step 2: Update your MicrobeDB database####
Sometimes the MySQL database schema needs to be changed. To check to see if it needs updating run the script:

./update_database_schema.pl


If you need any help:
morgan.g.i.langille@gmail.com
