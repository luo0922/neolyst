CREATE INDEX "idx_memories_agent_id" ON "mem0"."memories" (expr);
CREATE INDEX "idx_memories_updated_at" ON "mem0"."memories" (updated_at);
CREATE INDEX "idx_memories_hash" ON "mem0"."memories" (expr);
CREATE INDEX "memories_payload_idx" ON "mem0"."memories" (payload);
CREATE INDEX "idx_memories_user_id" ON "mem0"."memories" (expr);
CREATE INDEX "memories_hnsw_idx" ON "mem0"."memories" (vector);
CREATE INDEX "idx_memories_created_at" ON "mem0"."memories" (created_at);