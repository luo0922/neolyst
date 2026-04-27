CREATE INDEX "idx_dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector_vdb_ski" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_skills" (workspace);
CREATE INDEX "idx_lightrag_vdb_skills_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_skills" (id);
CREATE INDEX "idx_lightrag_vdb_skills_workspace_id" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_skills" (workspace, id);
CREATE INDEX "idx_lightrag_vdb_skills_hnsw_cosine" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_skills" (content_vector);