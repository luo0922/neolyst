ALTER TABLE "public"."analyst" ADD CONSTRAINT "analyst_email_key" UNIQUE (email);
ALTER TABLE "public"."analyst" ADD CONSTRAINT "analyst_pkey" PRIMARY KEY (id);