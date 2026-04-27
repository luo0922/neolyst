ALTER TABLE "kong"."routes" ADD CONSTRAINT "routes_service_id_fkey" FOREIGN KEY (service_id, ws_id) REFERENCES kong.services(id, ws_id);
ALTER TABLE "kong"."routes" ADD CONSTRAINT "routes_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "routes_tags_idx" ON "kong"."routes" (tags);
CREATE INDEX "routes_service_id_idx" ON "kong"."routes" (service_id);