CREATE TABLE IF NOT EXISTS "auth"."audit_log_entries"(
 "instance_id" uuid   ,
 "id" uuid   NOT NULL ,
 "payload" json   ,
 "created_at" timestamp with time zone   ,
 "ip_address" character varying(64)  DEFAULT ''::character varying   NOT NULL 
);
