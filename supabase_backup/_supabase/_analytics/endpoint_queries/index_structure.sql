ALTER TABLE "_analytics"."endpoint_queries" ADD CONSTRAINT "endpoint_queries_backend_id_fkey" FOREIGN KEY (backend_id) REFERENCES _analytics.backends(id) ON DELETE SET NULL;
ALTER TABLE "_analytics"."endpoint_queries" ADD CONSTRAINT "endpoint_queries_sandbox_query_id_fkey" FOREIGN KEY (sandbox_query_id) REFERENCES _analytics.endpoint_queries(id);
ALTER TABLE "_analytics"."endpoint_queries" ADD CONSTRAINT "endpoint_queries_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "endpoint_queries_user_id_index" ON "_analytics"."endpoint_queries" (user_id);
CREATE INDEX "endpoint_queries_token_index" ON "_analytics"."endpoint_queries" (token);
CREATE INDEX "endpoint_queries_backend_id_index" ON "_analytics"."endpoint_queries" (backend_id);