CREATE TABLE IF NOT EXISTS "_supavisor"."clusters"(
 "id" uuid   NOT NULL ,
 "active" boolean  DEFAULT false   NOT NULL ,
 "alias" character varying(255)   NOT NULL ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
