CREATE TABLE IF NOT EXISTS "net"."_http_response"(
 "id" bigint   ,
 "status_code" integer   ,
 "content_type" text   ,
 "headers" jsonb   ,
 "content" text   ,
 "timed_out" boolean   ,
 "error_msg" text   ,
 "created" timestamp with time zone  DEFAULT now()   NOT NULL 
);
