-- Convert schema '/home/mlangill/Dropbox/projects/MicrobeDB/information/INSTALL/microbedb_schema_old.sql' to '/home/mlangill/Dropbox/projects/MicrobeDB/information/INSTALL/microbedb_schema.sql':;

-- Update MicrobeDB Schema 0.1 to 1.0

BEGIN;

CREATE TABLE IF NOT EXISTS `microbedb_meta` (
  `meta_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `meta_key` varchar(255) NOT NULL,
  `meta_value` text,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `meta_key` (`meta_key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

ALTER TABLE gene CHANGE COLUMN gene_id gene_id integer(10) unsigned NOT NULL,
                 CHANGE COLUMN gene_strand gene_strand enum('+', '-', '1', '-1', '0') DEFAULT NULL,
                 ALTER TABLE gene;

ALTER TABLE genomeproject ADD COLUMN chromosome_num integer(10) unsigned DEFAULT 0,
                          ADD COLUMN plasmid_num integer(10) unsigned DEFAULT 0,
                          ADD COLUMN contig_num integer(10) unsigned DEFAULT 0,
                          CHANGE COLUMN gpv_id gpv_id integer(10) unsigned NOT NULL,
                          CHANGE COLUMN taxon_id taxon_id integer(10) unsigned DEFAULT 0,
                          ALTER TABLE genomeproject;

ALTER TABLE replicon DROP COLUMN genome_id,
                     CHANGE COLUMN rpv_id rpv_id integer(10) unsigned NOT NULL,
                     CHANGE COLUMN rep_type rep_type enum('chromosome', 'plasmid', 'contig') DEFAULT NULL,
                     CHANGE COLUMN file_name file_name text DEFAULT NULL,
                     ALTER TABLE replicon;

ALTER TABLE taxonomy CHANGE COLUMN taxon_id taxon_id integer(10) unsigned NOT NULL,
                     ALTER TABLE taxonomy;

ALTER TABLE version CHANGE COLUMN version_id version_id integer(11) NOT NULL,
                    ALTER TABLE version;


COMMIT;

