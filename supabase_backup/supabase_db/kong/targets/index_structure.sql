ALTER TABLE "kong"."targets" ADD CONSTRAINT "targets_upstream_id_fkey" FOREIGN KEY (upstream_id, ws_id) REFERENCES kong.upstreams(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."targets" ADD CONSTRAINT "targets_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "targets_target_idx" ON "kong"."targets" (target);
CREATE INDEX "targets_upstream_id_idx" ON "kong"."targets" (upstream_id);
CREATE INDEX "targets_tags_idx" ON "kong"."targets" (tags);