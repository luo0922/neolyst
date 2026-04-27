CREATE TABLE IF NOT EXISTS "net"."http_request_queue"(
 "id" bigserial   NOT NULL ,
 "method" net.http_method   NOT NULL ,
 "url" text   NOT NULL ,
 "headers" jsonb   ,
 "body" bytea   ,
 "timeout_milliseconds" integer   NOT NULL 
);
