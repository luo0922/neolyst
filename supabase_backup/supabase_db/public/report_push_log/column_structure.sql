CREATE TABLE IF NOT EXISTS "public"."report_push_log"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "report_id" uuid   NOT NULL ,
 "status" text   NOT NULL ,
 "http_status_code" integer   ,
 "response_body" text   ,
 "error_message" text   ,
 "payload_sent" jsonb   ,
 "trigger_type" text   NOT NULL ,
 "triggered_by" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
