ALTER TABLE "kong"."acme_storage" ADD CONSTRAINT "acme_storage_key_key" UNIQUE (key);
ALTER TABLE "kong"."acme_storage" ADD CONSTRAINT "acme_storage_pkey" PRIMARY KEY (id);