CREATE INDEX "reauthentication_token_idx" ON "auth"."users" (reauthentication_token);
CREATE INDEX "users_instance_id_idx" ON "auth"."users" (instance_id);
CREATE INDEX "email_change_token_current_idx" ON "auth"."users" (email_change_token_current);
CREATE INDEX "users_email_partial_key" ON "auth"."users" (email);
CREATE INDEX "confirmation_token_idx" ON "auth"."users" (confirmation_token);
CREATE INDEX "recovery_token_idx" ON "auth"."users" (recovery_token);
CREATE INDEX "email_change_token_new_idx" ON "auth"."users" (email_change_token_new);
CREATE INDEX "users_instance_id_email_idx" ON "auth"."users" (instance_id, lower);
CREATE INDEX "users_is_anonymous_idx" ON "auth"."users" (is_anonymous);