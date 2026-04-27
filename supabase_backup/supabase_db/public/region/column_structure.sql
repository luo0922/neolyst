CREATE TABLE IF NOT EXISTS "public"."region"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "name_en" text   NOT NULL ,
 "name_cn" text   NOT NULL ,
 "code" text   NOT NULL ,
 "is_active" boolean  DEFAULT true   NOT NULL 
);
