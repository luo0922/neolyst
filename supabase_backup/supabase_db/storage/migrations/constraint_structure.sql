ALTER TABLE "storage"."migrations" ADD CONSTRAINT "migrations_name_key" UNIQUE (name);
ALTER TABLE "storage"."migrations" ADD CONSTRAINT "migrations_pkey" PRIMARY KEY (id);