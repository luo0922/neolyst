ALTER TABLE "kong"."workspaces" ADD CONSTRAINT "workspaces_name_key" UNIQUE (name);
ALTER TABLE "kong"."workspaces" ADD CONSTRAINT "workspaces_pkey" PRIMARY KEY (id);