CREATE TABLE IF NOT EXISTS "kong"."clustering_rpc_requests"(
 "id" bigserial   NOT NULL ,
 "node_id" uuid   NOT NULL ,
 "reply_to" uuid   NOT NULL ,
 "ttl" timestamp with time zone   NOT NULL ,
 "payload" json   NOT NULL 
);
