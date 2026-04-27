CREATE TABLE IF NOT EXISTS "cron"."job_run_details"(
 "jobid" bigint   ,
 "runid" bigserial   NOT NULL ,
 "job_pid" integer   ,
 "database" text   ,
 "username" text   ,
 "command" text   ,
 "status" text   ,
 "return_message" text   ,
 "start_time" timestamp with time zone   ,
 "end_time" timestamp with time zone   
);
