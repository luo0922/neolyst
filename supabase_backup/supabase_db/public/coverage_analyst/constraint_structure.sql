ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_role_check" CHECK (((role >= 1) AND (role <= 4)));
ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_sort_order_check" CHECK (((sort_order >= 1) AND (sort_order <= 4)));
ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_uniq_pair" UNIQUE (coverage_id, analyst_id);
ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_uniq_sort" UNIQUE (coverage_id, sort_order);