CREATE TABLE IF NOT EXISTS "_analytics"."oauth_applications"(
 "id" bigserial   NOT NULL ,
 "owner_id" integer   NOT NULL ,
 "name" character varying(255)   NOT NULL ,
 "uid" character varying(255)   NOT NULL ,
 "secret" character varying(255)  DEFAULT ''::character varying   NOT NULL ,
 "redirect_uri" character varying(255)   NOT NULL ,
 "scopes" character varying(255)  DEFAULT ''::character varying   NOT NULL ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
