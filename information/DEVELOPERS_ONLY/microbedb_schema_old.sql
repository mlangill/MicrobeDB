-- MySQL dump 10.13  Distrib 5.1.41, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: microbedb
-- ------------------------------------------------------
-- Server version	5.1.41-3ubuntu12.9

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `gene`
--

DROP TABLE IF EXISTS `gene`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gene` (
  `gene_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `rpv_id` int(10) unsigned NOT NULL DEFAULT '0',
  `version_id` int(10) unsigned NOT NULL DEFAULT '0',
  `gpv_id` int(10) unsigned NOT NULL DEFAULT '0',
  `gid` int(10) unsigned DEFAULT '0',
  `pid` int(10) unsigned DEFAULT '0',
  `protein_accnum` char(12) DEFAULT '',
  `gene_type` enum('CDS','tRNA','rRNA','ncRNA','misc_RNA','tmRNA') NOT NULL,
  `gene_start` int(11) DEFAULT '0',
  `gene_end` int(11) DEFAULT '0',
  `gene_length` int(11) DEFAULT '0',
  `gene_strand` enum('+','-','1','-1','0') DEFAULT NULL,
  `gene_name` tinytext,
  `locus_tag` tinytext,
  `gene_product` text,
  `gene_seq` longtext,
  `protein_seq` longtext,
  PRIMARY KEY (`gene_id`),
  KEY `version_id` (`version_id`),
  KEY `gpv_id` (`gpv_id`),
  KEY `rpv_id` (`rpv_id`),
  KEY `protein_accnum` (`version_id`,`protein_accnum`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genomeproject`
--

DROP TABLE IF EXISTS `genomeproject`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genomeproject` (
  `gpv_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `gp_id` int(10) unsigned DEFAULT '0',
  `version_id` int(10) unsigned NOT NULL DEFAULT '0',
  `taxon_id` int(10) unsigned DEFAULT '0',
  `org_name` text,
  `gram_stain` enum('+','-','neither','unknown') DEFAULT 'unknown',
  `genome_gc` float(4,2) DEFAULT '0.00',
  `patho_status` enum('pathogen','nonpathogen','unknown') DEFAULT 'unknown',
  `disease` text,
  `genome_size` float(4,2) DEFAULT '0.00',
  `pathogenic_in` text,
  `temp_range` enum('unknown','cryophilic','psychrophilic','mesophilic','thermophilic','hyperthermophilic') DEFAULT 'unknown',
  `habitat` enum('unknown','host-associated','aquatic','terrestrial','specialized','multiple') DEFAULT 'unknown',
  `shape` text,
  `arrangement` text,
  `endospore` enum('yes','no','unknown') DEFAULT 'unknown',
  `motility` enum('yes','no','unknown') DEFAULT 'unknown',
  `salinity` text,
  `oxygen_req` enum('unknown','aerobic','microaerophilic','facultative','anaerobic') DEFAULT 'unknown',
  `release_date` date DEFAULT '0000-00-00',
  `centre` text,
  `gpv_directory` text,
  `chromosome_num` int(10) unsigned DEFAULT '0',
  `plasmid_num` int(10) unsigned DEFAULT '0',
  `contig_num` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`gpv_id`),
  KEY `version` (`version_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `microbedb_meta`
--

DROP TABLE IF EXISTS `microbedb_meta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `microbedb_meta` (
  `meta_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `meta_key` varchar(255) NOT NULL,
  `meta_value` text,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `meta_key` (`meta_key`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `replicon`
--

DROP TABLE IF EXISTS `replicon`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `replicon` (
  `rpv_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `gpv_id` int(10) unsigned NOT NULL DEFAULT '0',
  `version_id` int(10) unsigned NOT NULL DEFAULT '0',
  `rep_accnum` char(12) DEFAULT NULL,
  `definition` text,
  `rep_type` enum('chromosome','plasmid','contig') DEFAULT NULL,
  `rep_ginum` tinytext,
  `file_name` text,
  `cds_num` int(10) unsigned DEFAULT '0',
  `gene_num` int(10) unsigned DEFAULT '0',
  `protein_num` int(10) unsigned DEFAULT '0',
  `rep_size` int(10) unsigned DEFAULT '0',
  `rna_num` int(10) unsigned DEFAULT '0',
  `file_types` text,
  `rep_seq` longtext,
  PRIMARY KEY (`rpv_id`),
  KEY `version` (`version_id`),
  KEY `gpv_id` (`gpv_id`),
  KEY `rep_accnum` (`rep_accnum`,`version_id`) USING BTREE,
  KEY `rep_type` (`rep_type`,`version_id`) USING BTREE
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `taxonomy`
--

DROP TABLE IF EXISTS `taxonomy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `taxonomy` (
  `taxon_id` int(10) unsigned NOT NULL,
  `superkingdom` tinytext,
  `phylum` tinytext,
  `class` tinytext,
  `order` tinytext,
  `family` tinytext,
  `genus` tinytext,
  `species` tinytext,
  `other` tinytext,
  `synonyms` tinytext,
  PRIMARY KEY (`taxon_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `version`
--

DROP TABLE IF EXISTS `version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `version` (
  `version_id` int(11) NOT NULL AUTO_INCREMENT,
  `dl_directory` text,
  `version_date` date NOT NULL DEFAULT '0000-00-00',
  `used_by` text,
  PRIMARY KEY (`version_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-04-05 21:49:58
INSERT INTO `microbedb_meta` VALUES (1,'schema_version','3');
