CREATE TABLE IF NOT EXISTS "mem0"."memories"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "vector" vector(1024)   ,
 "payload" jsonb   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "updated_at" timestamp with time zone  DEFAULT CURRENT_TIMESTAMP   
);
