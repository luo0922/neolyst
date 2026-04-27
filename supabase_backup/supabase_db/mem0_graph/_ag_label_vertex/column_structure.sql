CREATE TABLE IF NOT EXISTS "mem0_graph"."_ag_label_vertex"(
 "id" ag_catalog.graphid  DEFAULT ag_catalog._graphid((ag_catalog._label_id('mem0_graph'::name, '_ag_label_vertex'::name))::integer, nextval('mem0_graph._ag_label_vertex_id_seq'::regclass))   NOT NULL ,
 "properties" ag_catalog.agtype  DEFAULT ag_catalog.agtype_build_map()   NOT NULL 
);
