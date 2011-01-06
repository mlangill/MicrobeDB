-- phpMyAdmin SQL Dump
-- version 3.2.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Sep 10, 2009 at 11:07 AM
-- Server version: 5.0.75
-- PHP Version: 5.2.6-3ubuntu4.2

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `microbedb`
--

-- --------------------------------------------------------

--
-- Table structure for table `gene`
--

CREATE TABLE IF NOT EXISTS `gene` (
  `gene_id` int(10) unsigned NOT NULL auto_increment,
  `rpv_id` int(10) unsigned NOT NULL default '0',
  `version_id` int(10) unsigned NOT NULL default '0',
  `gpv_id` int(10) unsigned NOT NULL default '0',
  `gid` int(10) unsigned default '0',
  `pid` int(10) unsigned default '0',
  `protein_accnum` char(12) default '',
  `gene_type` enum('CDS','tRNA','rRNA','ncRNA','misc_RNA','tmRNA') NOT NULL,
  `gene_start` int(11) default '0',
  `gene_end` int(11) default '0',
  `gene_length` int(11) default '0',
  `gene_strand` enum('+','-') default NULL,
  `gene_name` tinytext,
  `locus_tag` tinytext,
  `gene_product` text,
  `gene_seq` longtext,
  `protein_seq` longtext,
  PRIMARY KEY  (`gene_id`),
  KEY `version_id` (`version_id`),
  KEY `gpv_id` (`gpv_id`),
  KEY `rpv_id` (`rpv_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=3079147 ;

-- --------------------------------------------------------

--
-- Table structure for table `genomeproject`
--

CREATE TABLE IF NOT EXISTS `genomeproject` (
  `gpv_id` int(10) unsigned NOT NULL auto_increment,
  `gp_id` int(10) unsigned default '0',
  `version_id` int(10) unsigned NOT NULL default '0',
  `taxon_id` int(10) unsigned NOT NULL default '0',
  `org_name` text,
  `lineage` text,
  `gram_stain` enum('+','-','neither','unknown') default 'unknown',
  `genome_gc` float(4,2) default '0.00',
  `patho_status` enum('pathogen','nonpathogen','unknown') default 'unknown',
  `disease` text,
  `genome_size` float(4,2) default '0.00',
  `pathogenic_in` text,
  `temp_range` enum('unknown','cryophilic','psychrophilic','mesophilic','thermophilic','hyperthermophilic') default 'unknown',
  `habitat` enum('unknown','host-associated','aquatic','terrestrial','specialized','multiple') default 'unknown',
  `shape` text,
  `arrangement` text,
  `endospore` enum('yes','no','unknown') default 'unknown',
  `motility` enum('yes','no','unknown') default 'unknown',
  `salinity` enum('Non-halophilic','Mesophilic','Moderate halophile','Extreme halophile','unknown') default 'unknown',
  `oxygen_req` enum('unknown','aerobic','microaerophilic','facultative','anaerobic') default 'unknown',
  `release_date` date default '0000-00-00',
  `centre` text,
  `gpv_directory` text,
  PRIMARY KEY  (`gpv_id`),
  KEY `version` (`version_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC AUTO_INCREMENT=917 ;

-- --------------------------------------------------------

--
-- Table structure for table `replicon`
--

CREATE TABLE IF NOT EXISTS `replicon` (
  `rpv_id` int(10) unsigned NOT NULL auto_increment,
  `gpv_id` int(10) unsigned NOT NULL default '0',
  `version_id` int(10) unsigned NOT NULL default '0',
  `rep_accnum` char(12) default NULL,
  `definition` text,
  `rep_type` enum('chromosome','plasmid') default NULL,
  `rep_ginum` tinytext,
  `file_name` char(15) default NULL,
  `cds_num` int(10) unsigned default '0',
  `gene_num` int(10) unsigned default '0',
  `protein_num` int(10) unsigned default '0',
  `genome_id` int(10) unsigned default '0',
  `rep_size` int(10) unsigned default '0',
  `rna_num` int(10) unsigned default '0',
  `file_types` text,
  `rep_seq` longtext,
  PRIMARY KEY  (`rpv_id`),
  KEY `version` (`version_id`),
  KEY `gpv_id` (`gpv_id`),
  KEY `rep_accnum` USING BTREE (`rep_accnum`,`version_id`),
  KEY `rep_type` USING BTREE (`rep_type`,`version_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1727 ;

-- --------------------------------------------------------

--
-- Table structure for table `taxonomy`
--

CREATE TABLE IF NOT EXISTS `taxonomy` (
  `taxon_id` int(10) unsigned NOT NULL auto_increment,
  `superkingdom` tinytext,
  `phylum` tinytext,
  `class` tinytext,
  `order` tinytext,
  `family` tinytext,
  `genus` tinytext,
  `species` tinytext,
  `other` tinytext,
  `synonyms` tinytext,
  PRIMARY KEY  (`taxon_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=662599 ;

-- --------------------------------------------------------

--
-- Table structure for table `version`
--

CREATE TABLE IF NOT EXISTS `version` (
  `version_id` int(10) unsigned NOT NULL auto_increment,
  `dl_directory` text,
  `version_date` date NOT NULL default '0000-00-00',
  `used_by` text,
  PRIMARY KEY  (`version_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=2 ;
