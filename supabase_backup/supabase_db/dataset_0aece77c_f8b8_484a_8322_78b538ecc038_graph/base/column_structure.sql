CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph"."base"(
 "id" ag_catalog.graphid  DEFAULT ag_catalog._graphid((ag_catalog._label_id('dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph'::name, 'base'::name))::integer, nextval('dataset_0aece77c_f8b8_484a_8322_78b538ecc038_graph.base_id_seq'::regclass))   NOT NULL ,
 "properties" ag_catalog.agtype  DEFAULT ag_catalog.agtype_build_map()   NOT NULL 
);
