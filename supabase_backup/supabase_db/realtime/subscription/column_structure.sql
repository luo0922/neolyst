CREATE TABLE IF NOT EXISTS "realtime"."subscription"(
 "id" bigint   NOT NULL ,
 "subscription_id" uuid   NOT NULL ,
 "entity" regclass   NOT NULL ,
 "filters" realtime.user_defined_filter[]  DEFAULT '{}'::realtime.user_defined_filter[]   NOT NULL ,
 "claims" jsonb   NOT NULL ,
 "created_at" timestamp without time zone  DEFAULT timezone('utc'::text, now())   NOT NULL 
);
