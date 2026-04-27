ALTER TABLE "_analytics"."rules" ADD CONSTRAINT "rules_backend_id_fkey" FOREIGN KEY (backend_id) REFERENCES _analytics.backends(id) ON DELETE CASCADE;
ALTER TABLE "_analytics"."rules" ADD CONSTRAINT "rules_sink_fkey" FOREIGN KEY (sink) REFERENCES _analytics.sources(token) ON DELETE CASCADE;
ALTER TABLE "_analytics"."rules" ADD CONSTRAINT "rules_source_id_fkey" FOREIGN KEY (source_id) REFERENCES _analytics.sources(id) ON DELETE CASCADE;
CREATE INDEX "rules_token_index" ON "_analytics"."rules" (token);
CREATE INDEX "rules_source_id_index" ON "_analytics"."rules" (source_id);