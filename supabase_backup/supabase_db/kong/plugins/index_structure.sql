ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_route_id_fkey" FOREIGN KEY (route_id, ws_id) REFERENCES kong.routes(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_service_id_fkey" FOREIGN KEY (service_id, ws_id) REFERENCES kong.services(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "plugins_route_id_idx" ON "kong"."plugins" (route_id);
CREATE INDEX "plugins_service_id_idx" ON "kong"."plugins" (service_id);
CREATE INDEX "plugins_tags_idx" ON "kong"."plugins" (tags);
CREATE INDEX "plugins_name_idx" ON "kong"."plugins" (name);
CREATE INDEX "plugins_consumer_id_idx" ON "kong"."plugins" (consumer_id);