CREATE TABLE IF NOT EXISTS "kong"."clustering_sync_delta"(
 "version" integer   NOT NULL ,
 "type" text   NOT NULL ,
 "pk" json   NOT NULL ,
 "ws_id" uuid   NOT NULL ,
 "entity" json   
);
