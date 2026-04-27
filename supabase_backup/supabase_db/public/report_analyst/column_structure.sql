CREATE TABLE IF NOT EXISTS "public"."report_analyst"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "report_id" uuid   NOT NULL ,
 "analyst_id" uuid   NOT NULL ,
 "role" smallint   NOT NULL ,
 "sort_order" smallint   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
