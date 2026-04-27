ALTER TABLE "kong"."ca_certificates" ADD CONSTRAINT "ca_certificates_cert_digest_key" UNIQUE (cert_digest);
ALTER TABLE "kong"."ca_certificates" ADD CONSTRAINT "ca_certificates_pkey" PRIMARY KEY (id);