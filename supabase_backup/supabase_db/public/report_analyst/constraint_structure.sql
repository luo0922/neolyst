ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_role_check" CHECK (((role >= 1) AND (role <= 4)));
ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_sort_order_check" CHECK (((sort_order >= 1) AND (sort_order <= 4)));
ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_uniq_pair" UNIQUE (report_id, analyst_id);
ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_uniq_sort" UNIQUE (report_id, sort_order);