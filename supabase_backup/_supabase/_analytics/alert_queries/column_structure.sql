CREATE TABLE IF NOT EXISTS "_analytics"."alert_queries"(
 "id" bigserial   NOT NULL ,
 "name" character varying(255)   ,
 "token" uuid   ,
 "query" text   ,
 "description" text   ,
 "language" character varying(255)   ,
 "cron" character varying(255)   ,
 "source_mapping" jsonb   ,
 "slack_hook_url" character varying(255)   ,
 "webhook_notification_url" character varying(255)   ,
 "user_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
