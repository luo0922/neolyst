ALTER TABLE "mem0"."memory_migrations" ADD CONSTRAINT "memory_migrations_pkey" PRIMARY KEY (id);
ALTER TABLE "mem0"."memory_migrations" ADD CONSTRAINT "memory_migrations_user_id_key" UNIQUE (user_id);