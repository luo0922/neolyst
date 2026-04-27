CREATE TABLE IF NOT EXISTS "kong"."cluster_events"(
 "id" uuid   NOT NULL ,
 "node_id" uuid   NOT NULL ,
 "at" timestamp with time zone   NOT NULL ,
 "nbf" timestamp with time zone   ,
 "expire_at" timestamp with time zone   NOT NULL ,
 "channel" text   ,
 "data" text   
);
