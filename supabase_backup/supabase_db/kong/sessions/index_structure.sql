CREATE INDEX "session_sessions_expires_idx" ON "kong"."sessions" (expires);
CREATE INDEX "sessions_ttl_idx" ON "kong"."sessions" (ttl);