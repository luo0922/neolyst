ALTER TABLE "kong"."services" ADD CONSTRAINT "services_client_certificate_id_fkey" FOREIGN KEY (client_certificate_id, ws_id) REFERENCES kong.certificates(id, ws_id);
ALTER TABLE "kong"."services" ADD CONSTRAINT "services_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "services_fkey_client_certificate" ON "kong"."services" (client_certificate_id);
CREATE INDEX "services_tags_idx" ON "kong"."services" (tags);