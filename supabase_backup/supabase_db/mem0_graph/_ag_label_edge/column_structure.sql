CREATE TABLE IF NOT EXISTS "mem0_graph"."_ag_label_edge"(
 "id" ag_catalog.graphid  DEFAULT ag_catalog._graphid((ag_catalog._label_id('mem0_graph'::name, '_ag_label_edge'::name))::integer, nextval('mem0_graph._ag_label_edge_id_seq'::regclass))   NOT NULL ,
 "start_id" ag_catalog.graphid   NOT NULL ,
 "end_id" ag_catalog.graphid   NOT NULL ,
 "properties" ag_catalog.agtype  DEFAULT ag_catalog.agtype_build_map()   NOT NULL 
);
