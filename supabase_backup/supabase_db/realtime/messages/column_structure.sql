CREATE TABLE IF NOT EXISTS "realtime"."messages"(
 "topic" text   NOT NULL ,
 "extension" text   NOT NULL ,
 "payload" jsonb   ,
 "event" text   ,
 "private" boolean  DEFAULT false   ,
 "updated_at" timestamp without time zone  DEFAULT now()   NOT NULL ,
 "inserted_at" timestamp without time zone  DEFAULT now()   NOT NULL ,
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL 
);
