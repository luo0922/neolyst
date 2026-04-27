ALTER TABLE "auth"."saml_relay_states" ADD CONSTRAINT "saml_relay_states_flow_state_id_fkey" FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;
ALTER TABLE "auth"."saml_relay_states" ADD CONSTRAINT "saml_relay_states_sso_provider_id_fkey" FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;
CREATE INDEX "saml_relay_states_sso_provider_id_idx" ON "auth"."saml_relay_states" (sso_provider_id);
CREATE INDEX "saml_relay_states_created_at_idx" ON "auth"."saml_relay_states" (created_at);
CREATE INDEX "saml_relay_states_for_email_idx" ON "auth"."saml_relay_states" (for_email);