CREATE TABLE IF NOT EXISTS "public"."report_status_log"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "report_id" uuid   NOT NULL ,
 "from_status" text   NOT NULL ,
 "to_status" text   NOT NULL ,
 "action_by" uuid   NOT NULL ,
 "action_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "reason" text   ,
 "version_no" integer   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "action_by_name" text   
);
