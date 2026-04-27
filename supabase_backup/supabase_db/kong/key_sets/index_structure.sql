ALTER TABLE "kong"."key_sets" ADD CONSTRAINT "key_sets_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "key_sets_tags_idx" ON "kong"."key_sets" (tags);