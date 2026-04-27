ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_route_id_fkey" FOREIGN KEY (route_id) REFERENCES kong.routes(id) ON DELETE CASCADE;
ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_service_id_fkey" FOREIGN KEY (service_id) REFERENCES kong.services(id) ON DELETE CASCADE;
ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id) ON DELETE CASCADE;
CREATE INDEX "filter_chains_name_idx" ON "kong"."filter_chains" (name);
CREATE INDEX "filter_chains_cache_key_idx" ON "kong"."filter_chains" (cache_key);
CREATE INDEX "filter_chains_tags_idx" ON "kong"."filter_chains" (tags);