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

#This script looks for genomes with habitat listed as aquatic, and then prints out their genome sizes and GC%.

use strict;
use warnings;

#Import the MicrobeDB API                                                                                                                                       
use lib '../../../'; 
use MicrobeDB::Search;                                                                                                                                          

#intialize the search object                                                                                                                                    
my $search_obj= new MicrobeDB::Search();                                                                                                                               
                                                                                                                                                                        
#create the object that has properties that must match in the database                                                                                          
my $gp_obj= new MicrobeDB::GenomeProject(habitat => 'aquatic');                                                                                                                

#do the actual search                                                                                                                                           
my @genomes = $search_obj->object_search($gp_obj);                                                                                                                 
                                                                                                                                                                        
#loop through each genomes we found                                                                                                                                
foreach my $genome (@genomes){                                                                                                                                      

    #get the metadata we are interested in
    my $size = $genome->genome_size();
    my $gc=$genome->genome_gc();

    #print out a table of genomes
    print join("\t",$genome->org_name,$size,$gc),"\n";
}
