ALTER TABLE "kong"."acls" ADD CONSTRAINT "acls_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."acls" ADD CONSTRAINT "acls_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "acls_tags_idex_tags_idx" ON "kong"."acls" (tags);
CREATE INDEX "acls_group_idx" ON "kong"."acls" (group);
CREATE INDEX "acls_consumer_id_idx" ON "kong"."acls" (consumer_id);