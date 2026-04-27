CREATE INDEX "idx_lightrag_vdb_chunks_workspace_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_chunks" (workspace, id);
CREATE INDEX "idx_dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector_chunks_" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_chunks" (workspace);
CREATE INDEX "idx_lightrag_vdb_chunks_hnsw_cosine" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_chunks" (content_vector);
CREATE INDEX "idx_lightrag_vdb_chunks_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_chunks" (id);