CREATE TABLE IF NOT EXISTS "kong"."response_ratelimiting_metrics"(
 "identifier" text   NOT NULL ,
 "period" text   NOT NULL ,
 "period_date" timestamp with time zone   NOT NULL ,
 "service_id" uuid  DEFAULT '00000000-0000-0000-0000-000000000000'::uuid   NOT NULL ,
 "route_id" uuid  DEFAULT '00000000-0000-0000-0000-000000000000'::uuid   NOT NULL ,
 "value" integer   
);
