import "server-only";

import { err, ok, type Result } from "@/lib/result";
import type { PaginatedList } from "@/lib/pagination";
import { createServerClient } from "@/lib/supabase/server";

export type { PaginatedList };

// New schema: english_full_name -> english_name, chinese_short_name -> chinese_name
// Removed: ads_conversion_factor, is_duplicate, approved_by, approved_at
export type Coverage = {
  id: string;
  ticker: string;
  english_name: string;
  chinese_name: string | null;
  traditional_chinese: string | null;
  sector_id: string;
  isin: string;
  country_of_domicile: string;
  reporting_currency: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

// New schema: analyst_id -> analyst_email, sort_order -> author_order
export type CoverageAnalyst = {
  id: string;
  coverage_id: string;
  analyst_email: string;
  author_order: number;
  created_at: string;
  updated_at: string;
  // Joined analyst data
  analyst?: {
    email: string;
    english_name: string | null;
    chinese_name: string | null;
  };
};

export type CoverageWithDetails = Coverage & {
  sector?: {
    id: string;
    name_en: string;
    name_cn: string | null;
    level: number;
  };
  analysts: CoverageAnalyst[];
};

// Input type for creating/updating coverage analysts
export type CoverageAnalystInput = {
  analyst_email: string;
  author_order: number;
};

const PAGE_SIZE = 15;

/**
 * List coverages with pagination, search, and sector filter.
 * No FK constraints on sector_id / analyst_email — all joins done in JS.
 */
export async function listCoverages(params: {
  page: number;
  query: string | null;
  sector_id?: string | null;
}): Promise<Result<PaginatedList<CoverageWithDetails>>> {
  const supabase = await createServerClient();

  let queryBuilder = supabase
    .from("coverage")
    .select("*", { count: "exact" });

  if (params.query) {
    const searchTerm = `%${params.query}%`;
    queryBuilder = queryBuilder.or(
      `ticker.ilike.${searchTerm},english_name.ilike.${searchTerm},chinese_name.ilike.${searchTerm}`,
    );
  }

  if (params.sector_id) {
    queryBuilder = queryBuilder.eq("sector_id", params.sector_id);
  }

  const from = (params.page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const { data, error, count } = await queryBuilder
    .order("updated_at", { ascending: false })
    .range(from, to);

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch coverages");

  const total = count ?? 0;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  // JS-side joins: fetch sectors, coverage_analysts, and analysts
  const sectorIds = [
    ...new Set((data as Coverage[]).map((c) => c.sector_id).filter(Boolean)),
  ];
  const coverageIds = (data as Coverage[]).map((c) => c.id);
  const allAnalystEmails: string[] = [];

  const { data: sectorRows } = sectorIds.length
    ? await supabase.from("sector").select("id, name_en, name_cn, level").in("id", sectorIds)
    : { data: [] };
  const { data: caRows } = coverageIds.length
    ? await supabase
        .from("coverage_analyst")
        .select("id, coverage_id, analyst_email, author_order, created_at, updated_at")
        .in("coverage_id", coverageIds)
        .order("author_order", { ascending: true })
    : { data: [] };

  if (caRows) {
    for (const ca of caRows) {
      if (ca.analyst_email) allAnalystEmails.push(ca.analyst_email.toLowerCase());
    }
  }

  const { data: analystRows } = allAnalystEmails.length
    ? await supabase
        .from("analyst")
        .select("email, english_name, chinese_name")
        .in("email", [...new Set(allAnalystEmails)])
    : { data: [] };

  // Build lookup maps
  const sectorMap: Record<string, { id: string; name_en: string; name_cn: string | null; level: number }> = {};
  if (sectorRows) {
    for (const s of sectorRows) {
      sectorMap[s.id] = s;
    }
  }
  const analystMap: Record<string, { email: string; english_name: string | null; chinese_name: string | null }> = {};
  if (analystRows) {
    for (const a of analystRows) {
      // analyst.email is guaranteed lowercase by DB CHECK; normalize lookup key
      analystMap[a.email.toLowerCase()] = a;
    }
  }
  const caByCoverage: Record<string, CoverageAnalyst[]> = {};
  if (caRows) {
    for (const ca of caRows) {
      if (!caByCoverage[ca.coverage_id]) caByCoverage[ca.coverage_id] = [];
      caByCoverage[ca.coverage_id].push(ca);
    }
  }

  const items: CoverageWithDetails[] = (data as Coverage[]).map((c) => ({
    ...c,
    sector: sectorMap[c.sector_id] ?? undefined,
    analysts: (caByCoverage[c.id] ?? []).map((ca) => ({
      ...ca,
      analyst: analystMap[ca.analyst_email?.toLowerCase() ?? ""] ?? undefined,
    })),
  }));

  return ok({
    items,
    total,
    page: params.page,
    totalPages,
  });
}

/**
 * Get a single coverage by ID with details.
 * No FK constraints on sector_id / analyst_email — all joins done in JS.
 */
export async function getCoverage(
  id: string,
): Promise<Result<CoverageWithDetails>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("coverage")
    .select("*")
    .eq("id", id)
    .single();

  if (error) return err(error.message);
  if (!data) return err("Coverage not found");

  const coverage = data as Coverage;

  // JS-side joins: fetch sector, coverage_analysts, and analyst details
  const [{ data: sectorRow }, { data: caRows }] = await Promise.all([
    coverage.sector_id
      ? supabase
          .from("sector")
          .select("id, name_en, name_cn, level")
          .eq("id", coverage.sector_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    supabase
      .from("coverage_analyst")
      .select("id, coverage_id, analyst_email, author_order, created_at, updated_at")
      .eq("coverage_id", id)
      .order("author_order", { ascending: true }),
  ]);

  const analystEmails = (caRows ?? [])
    .map((ca) => ca.analyst_email?.toLowerCase() ?? "")
    .filter(Boolean);
  const { data: analystRows } = analystEmails.length
    ? await supabase
        .from("analyst")
        .select("email, english_name, chinese_name")
        .in("email", analystEmails)
    : { data: [] };

  const analystMap: Record<string, { email: string; english_name: string | null; chinese_name: string | null }> = {};
  if (analystRows) {
    for (const a of analystRows) {
      // analyst.email is guaranteed lowercase by DB CHECK; normalize lookup key
      analystMap[a.email.toLowerCase()] = a;
    }
  }

  const analysts: CoverageAnalyst[] = (caRows ?? []).map((ca) => ({
    ...ca,
    analyst: analystMap[ca.analyst_email?.toLowerCase() ?? ""] ?? undefined,
  }));

  return ok({
    ...coverage,
    sector: sectorRow ?? undefined,
    analysts,
  });
}

/**
 * Create a new coverage with analysts
 * analysts are linked via analyst_email (text, not uuid)
 */
export async function createCoverage(params: {
  ticker: string;
  country_of_domicile: string;
  english_name: string;
  chinese_name?: string | null;
  traditional_chinese?: string | null;
  sector_id: string;
  isin: string;
  reporting_currency?: string | null;
  analysts: CoverageAnalystInput[];
}): Promise<Result<CoverageWithDetails>> {
  const supabase = await createServerClient();

  // Validate analysts count
  if (params.analysts.length < 1 || params.analysts.length > 4) {
    return err("Coverage must have 1-4 analysts");
  }

  // Start transaction by creating coverage first
  const { data: coverage, error: coverageError } = await supabase
    .from("coverage")
    .insert({
      ticker: params.ticker,
      country_of_domicile: params.country_of_domicile,
      english_name: params.english_name,
      chinese_name: params.chinese_name ?? null,
      traditional_chinese: params.traditional_chinese ?? null,
      sector_id: params.sector_id,
      isin: params.isin,
      reporting_currency: params.reporting_currency ?? null,
    })
    .select()
    .single();

  if (coverageError) {
    if (coverageError.code === "23505") {
      if (coverageError.message.toLowerCase().includes("ticker")) {
        return err("Ticker already exists");
      }
      if (coverageError.message.toLowerCase().includes("isin")) {
        return err("ISIN already exists");
      }
    }
    return err(coverageError.message);
  }

  if (!coverage) return err("Failed to create coverage");

  // Create coverage_analyst relations using analyst_email
  const analystRecords = params.analysts.map((a) => ({
    coverage_id: coverage.id,
    analyst_email: a.analyst_email.toLowerCase(),
    author_order: a.author_order,
  }));

  const { error: analystsError } = await supabase
    .from("coverage_analyst")
    .insert(analystRecords);

  if (analystsError) {
    // Rollback: delete the coverage we just created
    await supabase.from("coverage").delete().eq("id", coverage.id);

    if (
      analystsError.message.toLowerCase().includes("4 analysts")
    ) {
      return err("A coverage can have at most 4 analysts");
    }
    return err(analystsError.message);
  }

  // Fetch the complete coverage with details
  return getCoverage(coverage.id);
}

/**
 * Update an existing coverage
 */
export async function updateCoverage(
  id: string,
  params: {
    ticker?: string;
    country_of_domicile?: string;
    english_name?: string;
    chinese_name?: string | null;
    traditional_chinese?: string | null;
    sector_id?: string;
    isin?: string;
    reporting_currency?: string | null;
    is_active?: boolean;
    analysts?: CoverageAnalystInput[];
  },
): Promise<Result<CoverageWithDetails>> {
  const supabase = await createServerClient();

  // Validate analysts count if provided
  if (params.analysts !== undefined) {
    if (params.analysts.length < 1 || params.analysts.length > 4) {
      return err("Coverage must have 1-4 analysts");
    }
  }

  // Update coverage record
  const updateData: Record<string, unknown> = {};
  if (params.ticker !== undefined) updateData.ticker = params.ticker;
  if (params.country_of_domicile !== undefined)
    updateData.country_of_domicile = params.country_of_domicile;
  if (params.english_name !== undefined)
    updateData.english_name = params.english_name;
  if (params.chinese_name !== undefined)
    updateData.chinese_name = params.chinese_name;
  if (params.traditional_chinese !== undefined)
    updateData.traditional_chinese = params.traditional_chinese;
  if (params.sector_id !== undefined) updateData.sector_id = params.sector_id;
  if (params.isin !== undefined) updateData.isin = params.isin;
  if (params.reporting_currency !== undefined)
    updateData.reporting_currency = params.reporting_currency;
  if (params.is_active !== undefined) updateData.is_active = params.is_active;

  if (Object.keys(updateData).length > 0) {
    const { error: updateError } = await supabase
      .from("coverage")
      .update(updateData)
      .eq("id", id);

    if (updateError) {
      if (updateError.code === "23505") {
        if (updateError.message.toLowerCase().includes("ticker")) {
          return err("Ticker already exists");
        }
        if (updateError.message.toLowerCase().includes("isin")) {
          return err("ISIN already exists");
        }
      }
      return err(updateError.message);
    }
  }

  // Update analysts if provided
  if (params.analysts !== undefined) {
    // Delete existing analysts
    const { error: deleteError } = await supabase
      .from("coverage_analyst")
      .delete()
      .eq("coverage_id", id);

    if (deleteError) return err(deleteError.message);

    // Insert new analysts using analyst_email
    const analystRecords = params.analysts.map((a) => ({
      coverage_id: id,
      analyst_email: a.analyst_email.toLowerCase(),
      author_order: a.author_order,
    }));

    const { error: insertError } = await supabase
      .from("coverage_analyst")
      .insert(analystRecords);

    if (insertError) {
      return err(insertError.message);
    }
  }

  return getCoverage(id);
}

/**
 * Delete a coverage
 */
export async function deleteCoverage(id: string): Promise<Result<null>> {
  const supabase = await createServerClient();

  const { error } = await supabase.from("coverage").delete().eq("id", id);

  if (error) return err(error.message);

  return ok(null);
}

/**
 * Get all active coverages (for stock quote sync)
 */
export async function listActiveCoverages(): Promise<Result<Coverage[]>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("coverage")
    .select("*")
    .eq("is_active", true);

  if (error) {
    console.error("Error fetching active coverages:", error);
    return err(error.message);
  }

  return ok(data ?? []);
}
