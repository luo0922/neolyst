CREATE TABLE IF NOT EXISTS "ag_catalog"."ag_label"(
 "name" name   NOT NULL ,
 "graph" oid   NOT NULL ,
 "id" ag_catalog.label_id   NOT NULL ,
 "kind" ag_catalog.label_kind   NOT NULL ,
 "relation" regclass   NOT NULL ,
 "seq_name" name   NOT NULL 
);
