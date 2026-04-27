CREATE INDEX "idx_lightrag_vdb_entity_hnsw_cosine" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_entity" (content_vector);
CREATE INDEX "idx_dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector_entity_" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_entity" (workspace);
CREATE INDEX "idx_lightrag_vdb_entity_workspace_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_entity" (workspace, id);
CREATE INDEX "idx_lightrag_vdb_entity_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_entity" (id);