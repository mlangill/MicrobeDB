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

#Example of how to use the search api to get information from microbedb using an object as the search field
#Searchable objects are:
#GenomeProject, Replicon, Gene, Version, or UpdateLog

#See table_search_example.pl, if you want to do a simple search on a mysql db table that is not part of the microbedb api  

#This script retrieves all annotated 16s genes and outputs them in fasta file format.

use warnings;
use strict;

use lib "../../../";

#we need to use the Search library (this also imports GenomeProject,Replicon, and Gene libs)
use MicrobeDB::Search;

warn "What version?\n";
my $version_id=<STDIN>;
chomp($version_id);
#Create an object with certain features that we want (e.g rep_type='chromosome')
my $rep_obj = new MicrobeDB::Replicon( version_id => $version_id);

#Create the search object.
my $search_obj = new MicrobeDB::Search();

#do the actual search using the replicon object to set the search parameters
#all objects that match the search criteria are returned as an array of the same type of objects
my @result_objs = $search_obj->object_search($rep_obj);

#iterate through each replicon object that was returned
foreach my $curr_rep_obj (@result_objs) {

	#get the name of the replicon
	my $rep_name = $curr_rep_obj->definition();
	
	#get the replicon accesion
	my $rep_accnum = $curr_rep_obj->rep_accnum();

	#get all genes associated with this chromosome
	my $genes = $curr_rep_obj->genes();

	foreach my $curr_gene (@$genes){
	    #check to see if the gene is annotated as a 16s rRNA
	    if($curr_gene->gene_type() eq 'rRNA'){
		my $rna_product = $curr_gene->gene_product();
		if(defined($rna_product) && $curr_gene->gene_product =~ /16s/i){
		my $gid = $curr_gene->gid();
		my $start = $curr_gene->gene_start();
		my $end = $curr_gene->gene_end();
		my $seq = $curr_gene->gene_seq();

		#print out the gene in fasta format
		print ">$rep_accnum|gi:$gid|$start - $end|$rna_product\n";
		print $seq . "\n";
		}
	    }
	}
}
