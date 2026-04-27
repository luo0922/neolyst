CREATE INDEX "ag_label_seq_name_graph_index" ON "ag_catalog"."ag_label" (seq_name, graph);
CREATE INDEX "ag_label_graph_oid_index" ON "ag_catalog"."ag_label" (graph, id);
CREATE INDEX "ag_label_name_graph_index" ON "ag_catalog"."ag_label" (name, graph);
CREATE INDEX "ag_label_relation_index" ON "ag_catalog"."ag_label" (relation);