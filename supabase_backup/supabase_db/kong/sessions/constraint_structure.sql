ALTER TABLE "kong"."sessions" ADD CONSTRAINT "sessions_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."sessions" ADD CONSTRAINT "sessions_session_id_key" UNIQUE (session_id);