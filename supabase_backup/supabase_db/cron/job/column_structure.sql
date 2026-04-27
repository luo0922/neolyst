CREATE TABLE IF NOT EXISTS "cron"."job"(
 "jobid" bigserial   NOT NULL ,
 "schedule" text   NOT NULL ,
 "command" text   NOT NULL ,
 "nodename" text  DEFAULT 'localhost'::text   NOT NULL ,
 "nodeport" integer  DEFAULT inet_server_port()   NOT NULL ,
 "database" text  DEFAULT current_database()   NOT NULL ,
 "username" text  DEFAULT CURRENT_USER   NOT NULL ,
 "active" boolean  DEFAULT true   NOT NULL ,
 "jobname" text   
);
