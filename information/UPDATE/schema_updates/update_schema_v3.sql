-- Convert schema './microbedb_schema_old.sql' to '../INSTALL/microbedb_schema.sql':;

BEGIN;

ALTER TABLE gene CHANGE COLUMN gene_id gene_id integer(10) unsigned NOT NULL auto_increment,
                 ADD INDEX protein_accnum (version_id, protein_accnum),
                 ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

ALTER TABLE genomeproject DROP COLUMN lineage,
                          CHANGE COLUMN gpv_id gpv_id integer(10) unsigned NOT NULL auto_increment,
                          CHANGE COLUMN salinity salinity text,
                          ENGINE=MyISAM ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET latin1;

ALTER TABLE microbedb_meta CHANGE COLUMN meta_id meta_id integer(10) unsigned NOT NULL auto_increment,
                           ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

ALTER TABLE replicon CHANGE COLUMN rpv_id rpv_id integer(10) unsigned NOT NULL auto_increment,
                     CHANGE COLUMN file_name file_name text,
                     ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

ALTER TABLE taxonomy ENGINE=MyISAM DEFAULT CHARACTER SET latin1;

ALTER TABLE version CHANGE COLUMN version_id version_id integer(11) NOT NULL auto_increment,
                    ENGINE=MyISAM DEFAULT CHARACTER SET latin1;


COMMIT;

