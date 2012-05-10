-- Convert schema './microbedb_schema_old.sql' to '../INSTALL/microbedb_schema.sql':;

BEGIN;

ALTER TABLE gene CHANGE COLUMN gene_id gene_id integer(10) unsigned NOT NULL auto_increment,
                 ADD INDEX gene_name (gene_name(100)),
                 ADD INDEX locus_tag (locus_tag(50)),
                 ADD INDEX gene_product (gene_product(100)),
                 ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

ALTER TABLE replicon CHANGE COLUMN rpv_id rpv_id integer(10) unsigned NOT NULL auto_increment,
                     CHANGE COLUMN file_name file_name text,
                     ADD INDEX definition (definition(100)),
                     ADD INDEX rep_ginum (rep_ginum(100)),
                     ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

COMMIT;

