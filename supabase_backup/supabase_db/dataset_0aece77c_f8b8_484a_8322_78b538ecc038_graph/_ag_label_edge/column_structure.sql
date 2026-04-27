CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."_ag_label_edge"(
 "id" ag_catalog.graphid  DEFAULT ag_catalog._graphid((ag_catalog._label_id('dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph'::name, '_ag_label_edge'::name))::integer, nextval('dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph._ag_label_edge_id_seq'::regclass))   NOT NULL ,
 "start_id" ag_catalog.graphid   NOT NULL ,
 "end_id" ag_catalog.graphid   NOT NULL ,
 "properties" ag_catalog.agtype  DEFAULT ag_catalog.agtype_build_map()   NOT NULL 
);
