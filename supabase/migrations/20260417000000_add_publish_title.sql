-- Add publish_title column to reports and implement automatic generation logic
BEGIN;

-- 1. Add publish_title column to report table (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'report' AND column_name = 'publish_title'
  ) THEN
    ALTER TABLE public.report ADD COLUMN publish_title text;
  END IF;
END $$;

-- 2. RPC: get last published rating and target_price from snapshot_json
-- Returns the most recent published report's rating/target_price for a given coverage,
-- skipping any records where rating = 'Non-rated'.
CREATE OR REPLACE FUNCTION public.get_last_published_rating_and_targetprice(p_coverage_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT rv.snapshot_json
  INTO v_result
  FROM public.report r
  JOIN public.report_version rv ON rv.report_id = r.id
  WHERE r.coverage_id = p_coverage_id
    AND r.status = 'published'
    AND rv.snapshot_json->>'rating' IS NOT NULL
    AND (rv.snapshot_json->>'rating')::text <> 'Non-rated'
  ORDER BY r.published_at DESC
  LIMIT 1;

  RETURN v_result;
END;
$$;

-- 3. RPC: generate publish_title for a given report
-- Company type: initiation or rating/target-price change format
-- Other types: publish_title = title
-- p_rating and p_target_price are passed from the save operation's pending values
CREATE OR REPLACE FUNCTION public.generate_publish_title(
  p_report_id uuid,
  p_rating text,
  p_target_price text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_report record;
  v_coverage record;
  v_last jsonb;
  v_last_rating text;
  v_last_target_price numeric;
  v_current_rating text;
  v_current_target_price numeric;
  v_chinese_short text;
  v_ticker text;
  v_english_full text;
  v_rating_change_cn text := '';
  v_rating_change_en text := '';
  v_price_change_cn text := '';
  v_price_change_en text := '';
  v_pct numeric;
BEGIN
  -- Get current report info from table (not snapshot yet)
  SELECT report_type, title, coverage_id
  INTO v_report
  FROM public.report
  WHERE id = p_report_id;

  IF NOT FOUND OR v_report.report_type IS NULL THEN
    RETURN NULL;
  END IF;

  -- Company type: generate with rating/target-price logic
  IF v_report.report_type = 'company' AND v_report.coverage_id IS NOT NULL THEN
    -- Use the rating/target_price from the pending save operation
    v_current_rating := NULLIF(btrim(COALESCE(p_rating, '')), '');
    v_current_target_price := NULLIF(btrim(COALESCE(p_target_price, '')), '')::numeric;

    -- Get coverage info
    SELECT chinese_short_name, ticker, english_full_name
    INTO v_chinese_short, v_ticker, v_english_full
    FROM public.coverage
    WHERE id = v_report.coverage_id;

    -- Get last published report's snapshot
    v_last := public.get_last_published_rating_and_targetprice(v_report.coverage_id);

    -- Extract last rating/target_price
    IF v_last IS NOT NULL THEN
      v_last_rating := v_last->>'rating';
      v_last_target_price := NULLIF(v_last->>'target_price', '')::numeric;
    END IF;

    -- Initiation (first coverage)
    IF v_last IS NULL OR v_last_rating IS NULL THEN
      v_rating_change_cn := '首次覆盖：';
      v_rating_change_en := ': Initiation';
    ELSIF v_current_rating IS NULL OR v_current_rating = '' OR v_current_rating = 'Non-rated' THEN
      -- Non-rated: no rating change shown
      v_rating_change_cn := '';
      v_rating_change_en := '';
    ELSE
      -- Rating change mapping
      CASE
        WHEN v_current_rating = 'OUTPERFORM' AND v_last_rating = 'OUTPERFORM' THEN
          v_rating_change_cn := '—维持优于大市'; v_rating_change_en := '—Maintain OP';
        WHEN v_current_rating = 'OUTPERFORM' AND v_last_rating IN ('NEUTRAL', 'UNDERPERFORM') THEN
          v_rating_change_cn := '—上调至优于大市'; v_rating_change_en := '—UG to OP';
        WHEN v_current_rating = 'NEUTRAL' AND v_last_rating = 'UNDERPERFORM' THEN
          v_rating_change_cn := '—上调至中性'; v_rating_change_en := '—UG to NEUTRAL';
        WHEN v_current_rating = 'NEUTRAL' AND v_last_rating = 'NEUTRAL' THEN
          v_rating_change_cn := '—维持中性'; v_rating_change_en := '—Maintain NEUTRAL';
        WHEN v_current_rating = 'NEUTRAL' AND v_last_rating = 'OUTPERFORM' THEN
          v_rating_change_cn := '—下调至中性'; v_rating_change_en := '—DG to NEUTRAL';
        WHEN v_current_rating = 'UNDERPERFORM' AND v_last_rating IN ('OUTPERFORM', 'NEUTRAL') THEN
          v_rating_change_cn := '—下调至弱于大市'; v_rating_change_en := '—DG to UP';
        WHEN v_current_rating = 'UNDERPERFORM' AND v_last_rating = 'UNDERPERFORM' THEN
          v_rating_change_cn := '—维持弱于大市'; v_rating_change_en := '—Maintain UP';
        ELSE
          v_rating_change_cn := ''; v_rating_change_en := '';
      END CASE;

      -- Target price change
      IF v_current_target_price IS NOT NULL AND v_last_target_price IS NOT NULL AND v_last_target_price > 0 THEN
        IF v_current_target_price > v_last_target_price THEN
          v_pct := ROUND((v_current_target_price - v_last_target_price) / v_last_target_price * 100, 1);
          v_price_change_cn := '; 上调目标价' || v_pct::text || '%';
          v_price_change_en := ' & Raise TP by ' || v_pct::text || '%';
        ELSIF v_current_target_price < v_last_target_price THEN
          v_pct := ROUND((v_last_target_price - v_current_target_price) / v_last_target_price * 100, 1);
          v_price_change_cn := '; 下调目标价' || v_pct::text || '%';
          v_price_change_en := ' & Cut TP by ' || v_pct::text || '%';
        END IF;
      END IF;
    END IF;

    -- Build final title
    RETURN COALESCE(v_chinese_short, '') || ' (' || COALESCE(v_ticker, '') || ')：'
           || COALESCE(v_report.title, '') || v_rating_change_cn || COALESCE(v_price_change_cn, '')
           || '（' || COALESCE(v_english_full, '') || '：' || COALESCE(v_report.title, '')
           || v_rating_change_en || COALESCE(v_price_change_en, '') || '）';

  ELSE
    -- Non-company types: publish_title = title
    RETURN v_report.title;
  END IF;
END;
$$;

-- 4. Update report_save_content_atomic to generate and persist publish_title
DO $$
BEGIN
  DROP FUNCTION IF EXISTS public.report_save_content_atomic(
    uuid, text, text, text, text, text, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid,
    text, text, text, text, text, text, text
  );
END $$;

CREATE OR REPLACE FUNCTION public.report_save_content_atomic(
  p_report_id uuid,
  p_title text,
  p_report_type text,
  p_ticker text,
  p_rating text,
  p_target_price text,
  p_region_code text,
  p_sector_id uuid,
  p_report_language text,
  p_contact_person_id uuid,
  p_investment_thesis text,
  p_certificate_confirmed boolean,
  p_coverage_id uuid,
  p_analysts jsonb,
  p_changed_by uuid,
  p_word_file_path text,
  p_pdf_file_path text,
  p_model_file_path text,
  p_word_file_name text,
  p_pdf_file_name text,
  p_model_file_name text
)
RETURNS public.report
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $BODY$
DECLARE
  v_report public.report;
  v_current_version_no integer;
  v_publish_title text;
BEGIN
  SELECT current_version_no INTO v_current_version_no
  FROM public.report WHERE id = p_report_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  -- Generate publish_title using pending rating/target_price values
  v_publish_title := public.generate_publish_title(p_report_id, p_rating, p_target_price);

  -- Update report table
  UPDATE public.report
  SET
    title = p_title,
    report_type = p_report_type,
    ticker = nullif(btrim(coalesce(p_ticker, '')), ''),
    rating = nullif(btrim(coalesce(p_rating, '')), ''),
    target_price = CASE WHEN p_target_price IS NULL OR btrim(p_target_price) = '' THEN NULL ELSE p_target_price::numeric END,
    region_code = p_region_code,
    sector_id = p_sector_id,
    report_language = p_report_language,
    contact_person_id = p_contact_person_id,
    investment_thesis = p_investment_thesis,
    certificate_confirmed = p_certificate_confirmed,
    coverage_id = p_coverage_id,
    current_version_no = v_current_version_no + 1,
    publish_title = v_publish_title,
    updated_at = NOW()
  WHERE id = p_report_id
  RETURNING * INTO v_report;

  -- Insert new version record
  INSERT INTO public.report_version (
    id, report_id, version_no, snapshot_json,
    word_file_path, pdf_file_path, model_file_path,
    word_file_name, pdf_file_name, model_file_name,
    changed_by, changed_at, created_at
  ) VALUES (
    gen_random_uuid(),
    p_report_id,
    v_current_version_no + 1,
    jsonb_build_object(
      'title', p_title, 'report_type', p_report_type, 'ticker', p_ticker,
      'rating', p_rating, 'target_price', p_target_price,
      'region_code', p_region_code, 'sector_id', p_sector_id,
      'report_language', p_report_language,
      'contact_person_id', p_contact_person_id,
      'investment_thesis', p_investment_thesis,
      'certificate_confirmed', p_certificate_confirmed,
      'coverage_id', p_coverage_id,
      'analysts', p_analysts
    ),
    p_word_file_path, p_pdf_file_path, p_model_file_path,
    p_word_file_name, p_pdf_file_name, p_model_file_name,
    p_changed_by, NOW(), NOW()
  );

  -- Replace analyst associations
  DELETE FROM public.report_analyst WHERE report_id = p_report_id;
  IF p_analysts IS NOT NULL AND jsonb_array_length(p_analysts) > 0 THEN
    INSERT INTO public.report_analyst (id, report_id, analyst_id, role, sort_order, created_at, updated_at)
    SELECT
      gen_random_uuid(), p_report_id,
      (elem->>'analyst_id')::uuid,
      (elem->>'role')::smallint,
      (elem->>'sort_order')::smallint,
      NOW(), NOW()
    FROM jsonb_array_elements(p_analysts) AS elem;
  END IF;

  RETURN v_report;
END;
$BODY$;

COMMIT;
