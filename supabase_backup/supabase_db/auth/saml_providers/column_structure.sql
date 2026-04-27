CREATE TABLE IF NOT EXISTS "auth"."saml_providers"(
 "id" uuid   NOT NULL ,
 "sso_provider_id" uuid   NOT NULL ,
 "entity_id" text   NOT NULL ,
 "metadata_xml" text   NOT NULL ,
 "metadata_url" text   ,
 "attribute_mapping" jsonb   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "name_id_format" text   
);
