CREATE TABLE IF NOT EXISTS "supabase_functions"."hooks"(
 "id" bigserial   NOT NULL ,
 "hook_table_id" integer   NOT NULL ,
 "hook_name" text   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "request_id" bigint   
);
