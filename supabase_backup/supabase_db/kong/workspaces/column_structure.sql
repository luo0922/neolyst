CREATE TABLE IF NOT EXISTS "kong"."workspaces"(
 "id" uuid   NOT NULL ,
 "name" text   ,
 "comment" text   ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "meta" jsonb   ,
 "config" jsonb   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
