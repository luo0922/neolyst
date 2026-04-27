CREATE TABLE IF NOT EXISTS "public"."coverage"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "ticker" text   NOT NULL ,
 "english_full_name" text   NOT NULL ,
 "chinese_short_name" text   ,
 "traditional_chinese" text   ,
 "sector_id" uuid   NOT NULL ,
 "isin" text   NOT NULL ,
 "country_of_domicile" text   NOT NULL ,
 "reporting_currency" text   ,
 "ads_conversion_factor" numeric(18,6)   ,
 "is_duplicate" boolean  DEFAULT false   NOT NULL ,
 "approved_by" uuid   ,
 "approved_at" timestamp with time zone   ,
 "is_active" boolean  DEFAULT true   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "index_code" text   
);
