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

#This script prints out a fasta formatted list of 'recA' genes from genomes that are described as pathogens.

use strict;
use warnings;

#Import the MicrobeDB API                                                                                                                                       
use lib '../../../'; 
use MicrobeDB::Search;                                                                                                                                          

#intialize the search object                                                                                                                                    
my $search_obj= new MicrobeDB::Search();                                                                                                                               
                                                                                                                                                                        
#create the object that has properties that must match in the database                                                                                          
my $gene_obj= new MicrobeDB::Gene(gene_name => 'recA');                                                                                                                

#do the actual search                                                                                                                                           
my @genes = $search_obj->object_search($gene_obj);                                                                                                                 
                                                                                                                                                                        
#loop through each gene we found                                                                                                                                
foreach my $gene (@genes){                                                                                                                                      
    
    #get genome associated with this gene
    my $genome=$gene->genomeproject();
    
    #only interested in 'pathogen' genomes
    if(defined($genome->patho_status()) && $genome->patho_status() eq 'pathogen'){

	#print out the fasta header line using information from the genome and from the gene
	print '>',$genome->org_name(),'|',$gene->gid,'|',$gene->gene_name(),"\n";

	#print out the DNA sequence
	print $gene->gene_seq(),"\n"; 
    }
}
