-- Convert schema '/home/mlangill/Dropbox/projects/MicrobeDB/information//DEVELOPERS_ONLY/microbedb_schema_old.sql' to '/home/mlangill/Dropbox/projects/MicrobeDB/information//INSTALL/microbedb_schema.sql':;

BEGIN;

ALTER TABLE genomeproject DROP COLUMN lineage,
                          CHANGE COLUMN salinity salinity text;


COMMIT;

