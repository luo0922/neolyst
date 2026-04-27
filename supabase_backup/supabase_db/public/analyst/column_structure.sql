CREATE TABLE IF NOT EXISTS "public"."analyst"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "full_name" text   NOT NULL ,
 "chinese_name" text   ,
 "email" citext   NOT NULL ,
 "suffix" text   ,
 "sfc" text   ,
 "is_active" boolean  DEFAULT true   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "region_code" text   
);
