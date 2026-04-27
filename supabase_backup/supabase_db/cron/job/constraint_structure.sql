ALTER TABLE "cron"."job" ADD CONSTRAINT "job_pkey" PRIMARY KEY (jobid);
ALTER TABLE "cron"."job" ADD CONSTRAINT "jobname_username_uniq" UNIQUE (jobname, username);