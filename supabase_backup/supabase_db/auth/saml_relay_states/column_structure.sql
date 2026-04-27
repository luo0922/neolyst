CREATE TABLE IF NOT EXISTS "auth"."saml_relay_states"(
 "id" uuid   NOT NULL ,
 "sso_provider_id" uuid   NOT NULL ,
 "request_id" text   NOT NULL ,
 "for_email" text   ,
 "redirect_to" text   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "flow_state_id" uuid   
);
