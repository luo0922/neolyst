CREATE TABLE IF NOT EXISTS "public"."sector"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "level" smallint   NOT NULL ,
 "parent_id" uuid   ,
 "name_en" text   NOT NULL ,
 "name_cn" text   ,
 "wind_name" text   ,
 "is_active" boolean  DEFAULT true   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
