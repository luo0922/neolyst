ALTER TABLE "kong"."sm_vaults" ADD CONSTRAINT "sm_vaults_id_ws_id_key" UNIQUE (id, ws_id);
ALTER TABLE "kong"."sm_vaults" ADD CONSTRAINT "sm_vaults_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."sm_vaults" ADD CONSTRAINT "sm_vaults_prefix_key" UNIQUE (prefix);
ALTER TABLE "kong"."sm_vaults" ADD CONSTRAINT "sm_vaults_prefix_ws_id_key" UNIQUE (prefix, ws_id);