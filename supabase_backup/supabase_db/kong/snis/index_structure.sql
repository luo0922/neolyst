ALTER TABLE "kong"."snis" ADD CONSTRAINT "snis_certificate_id_fkey" FOREIGN KEY (certificate_id, ws_id) REFERENCES kong.certificates(id, ws_id);
ALTER TABLE "kong"."snis" ADD CONSTRAINT "snis_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "snis_tags_idx" ON "kong"."snis" (tags);
CREATE INDEX "snis_certificate_id_idx" ON "kong"."snis" (certificate_id);