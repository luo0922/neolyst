ALTER TABLE "kong"."sm_vaults" ADD CONSTRAINT "sm_vaults_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "sm_vaults_tags_idx" ON "kong"."sm_vaults" (tags);