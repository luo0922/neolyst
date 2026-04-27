ALTER TABLE "kong"."upstreams" ADD CONSTRAINT "upstreams_client_certificate_id_fkey" FOREIGN KEY (client_certificate_id) REFERENCES kong.certificates(id);
ALTER TABLE "kong"."upstreams" ADD CONSTRAINT "upstreams_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "upstreams_fkey_client_certificate" ON "kong"."upstreams" (client_certificate_id);
CREATE INDEX "upstreams_tags_idx" ON "kong"."upstreams" (tags);