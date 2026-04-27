ALTER TABLE "_realtime"."extensions" ADD CONSTRAINT "extensions_tenant_external_id_fkey" FOREIGN KEY (tenant_external_id) REFERENCES _realtime.tenants(external_id) ON DELETE CASCADE;
CREATE INDEX "extensions_tenant_external_id_type_index" ON "_realtime"."extensions" (tenant_external_id, type);
CREATE INDEX "extensions_tenant_external_id_index" ON "_realtime"."extensions" (tenant_external_id);