ALTER TABLE "kong"."certificates" ADD CONSTRAINT "certificates_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "certificates_tags_idx" ON "kong"."certificates" (tags);