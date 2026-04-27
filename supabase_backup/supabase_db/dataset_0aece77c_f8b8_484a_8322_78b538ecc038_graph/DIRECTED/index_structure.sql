CREATE INDEX "directed_eid_idx" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."DIRECTED" (end_id);
CREATE INDEX "directed_seid_idx" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."DIRECTED" (start_id, end_id);
CREATE INDEX "directed_p_idx" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."DIRECTED" (id);
CREATE INDEX "directed_sid_idx" ON "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."DIRECTED" (start_id);