-- Convert schema '/home/mlangill/Dropbox/projects/MicrobeDB/information/INSTALL/microbedb_schema_old.sql' to '/home/mlangill/Dropbox/projects/MicrobeDB/information/INSTALL/microbedb_schema.sql':;

BEGIN;

ALTER TABLE gene CHANGE COLUMN gene_id gene_id integer(10) unsigned NOT NULL,
                 CHANGE COLUMN gene_strand gene_strand enum('+', '-', '1', '-1', '0') DEFAULT NULL,
                 ALTER TABLE gene;

ALTER TABLE genomeproject CHANGE COLUMN gpv_id gpv_id integer(10) unsigned NOT NULL,
                          CHANGE COLUMN taxon_id taxon_id integer(10) unsigned DEFAULT 0,
                          ALTER TABLE genomeproject;

ALTER TABLE replicon CHANGE COLUMN rpv_id rpv_id integer(10) unsigned NOT NULL,
                     CHANGE COLUMN rep_type rep_type enum('chromosome', 'plasmid', 'contig') DEFAULT NULL,
                     CHANGE COLUMN file_name file_name text DEFAULT NULL,
                     ALTER TABLE replicon;

ALTER TABLE taxonomy CHANGE COLUMN taxon_id taxon_id integer(10) unsigned NOT NULL,
                     ALTER TABLE taxonomy;

ALTER TABLE version CHANGE COLUMN version_id version_id integer(11) NOT NULL,
                    ALTER TABLE version;


COMMIT;

