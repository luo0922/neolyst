ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_set_id_fkey" FOREIGN KEY (set_id) REFERENCES kong.key_sets(id) ON DELETE CASCADE;
ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "keys_tags_idx" ON "kong"."keys" (tags);
CREATE INDEX "keys_fkey_key_sets" ON "kong"."keys" (set_id);