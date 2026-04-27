ALTER TABLE "kong"."consumers" ADD CONSTRAINT "consumers_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "consumers_username_idx" ON "kong"."consumers" (lower);
CREATE INDEX "consumers_tags_idx" ON "kong"."consumers" (tags);