CREATE INDEX "idx_auth_code" ON "auth"."flow_state" (auth_code);
CREATE INDEX "idx_user_id_auth_method" ON "auth"."flow_state" (user_id, authentication_method);
CREATE INDEX "flow_state_created_at_idx" ON "auth"."flow_state" (created_at);