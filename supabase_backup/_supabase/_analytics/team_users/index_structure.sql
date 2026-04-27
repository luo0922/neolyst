ALTER TABLE "_analytics"."team_users" ADD CONSTRAINT "team_users_team_id_fkey" FOREIGN KEY (team_id) REFERENCES _analytics.teams(id) ON DELETE CASCADE;
CREATE INDEX "team_users_team_id_index" ON "_analytics"."team_users" (team_id);
CREATE INDEX "team_users_provider_uid_team_id_index" ON "_analytics"."team_users" (provider_uid, team_id);