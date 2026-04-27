ALTER TABLE "storage"."objects" ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);
CREATE INDEX "bucketid_objname" ON "storage"."objects" (bucket_id, name);
CREATE INDEX "objects_bucket_id_level_idx" ON "storage"."objects" (bucket_id, level, name);
CREATE INDEX "idx_objects_bucket_id_name" ON "storage"."objects" (bucket_id, name);
CREATE INDEX "idx_objects_lower_name" ON "storage"."objects" (path_tokens, lower, bucket_id, level);
CREATE INDEX "idx_name_bucket_level_unique" ON "storage"."objects" (name, bucket_id, level);
CREATE INDEX "name_prefix_search" ON "storage"."objects" (name);