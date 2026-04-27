INSERT INTO "cron"."job" ("jobid", "schedule", "command", "nodename", "nodeport", "database", "username", "active", "jobname") VALUES 
('1', '* * * * *', 'update _analytics.users set updated_at = now() where id = 1', '/tmp', '5432', '_supabase', 'postgres', true, 'minutely:update_analytics_users_id1');
