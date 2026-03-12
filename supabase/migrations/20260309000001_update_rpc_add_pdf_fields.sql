-- Update report_save_content_atomic RPC function: add pdf_file_path and pdf_file_name
-- Drop and recreate in a single statement using DO block
DO $$
BEGIN
  -- Drop the old function first (to avoid function signature conflict)
  DROP FUNCTION IF EXISTS public.report_save_content_atomic(uuid, text, text, text, text, numeric, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text, text, text);

  -- Create the new function with PDF fields
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
  AS $$
  DECLARE
    v_report public.report;
    v_current_version_no integer;
    v_updated public.report;
  BEGIN
    -- Get current version number
    SELECT current_version_no INTO v_current_version_no
    FROM public.report
    WHERE id = p_report_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Report not found';
    END IF;

    -- Update report table
    UPDATE public.report
    SET
      title = p_title,
      report_type = p_report_type,
      ticker = p_ticker,
      rating = p_rating,
      target_price = CASE WHEN p_target_price IS NULL OR p_target_price = '' THEN NULL ELSE p_target_price::numeric END,
      region_code = p_region_code,
      sector_id = p_sector_id,
      report_language = p_report_language,
      contact_person_id = p_contact_person_id,
      investment_thesis = p_investment_thesis,
      certificate_confirmed = p_certificate_confirmed,
      coverage_id = p_coverage_id,
      current_version_no = v_current_version_no + 1,
      updated_at = NOW()
    WHERE id = p_report_id
    RETURNING * INTO v_report;

    -- Insert new version record
    INSERT INTO public.report_version (
      id,
      report_id,
      version_no,
      snapshot_json,
      word_file_path,
      pdf_file_path,
      model_file_path,
      word_file_name,
      pdf_file_name,
      model_file_name,
      changed_by,
      changed_at,
      created_at
    ) VALUES (
      gen_random_uuid(),
      p_report_id,
      v_current_version_no + 1,
      jsonb_build_object(
        'title', p_title,
        'report_type', p_report_type,
        'ticker', p_ticker,
        'rating', p_rating,
        'target_price', p_target_price,
        'region_code', p_region_code,
        'sector_id', p_sector_id,
        'report_language', p_report_language,
        'contact_person_id', p_contact_person_id,
        'investment_thesis', p_investment_thesis,
        'certificate_confirmed', p_certificate_confirmed,
        'coverage_id', p_coverage_id,
        'analysts', p_analysts
      ),
      p_word_file_path,
      p_pdf_file_path,
      p_model_file_path,
      p_word_file_name,
      p_pdf_file_name,
      p_model_file_name,
      p_changed_by,
      NOW(),
      NOW()
    );

    -- Delete old analyst associations and insert new ones
    DELETE FROM public.report_analyst WHERE report_id = p_report_id;

    IF p_analysts IS NOT NULL AND jsonb_array_length(p_analysts) > 0 THEN
      INSERT INTO public.report_analyst (id, report_id, analyst_id, role, sort_order, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        p_report_id,
        (elem->>'analyst_id')::uuid,
        (elem->>'role')::smallint,
        (elem->>'sort_order')::smallint,
        NOW(),
        NOW()
      FROM jsonb_array_elements(p_analysts) AS elem;
    END IF;

    RETURN v_report;
  END;
  $$;
END $$;
