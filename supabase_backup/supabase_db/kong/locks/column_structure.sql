CREATE TABLE IF NOT EXISTS "kong"."locks"(
 "key" text   NOT NULL ,
 "owner" text   ,
 "ttl" timestamp with time zone   
);
