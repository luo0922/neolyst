ALTER TABLE "auth"."sso_domains" ADD CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0));
ALTER TABLE "auth"."sso_domains" ADD CONSTRAINT "sso_domains_pkey" PRIMARY KEY (id);