import "server-only";

import { err, ok, type Result } from "@/lib/result";
import type { PaginatedList } from "@/lib/pagination";
import { createServerClient } from "@/lib/supabase/server";

export type { PaginatedList };

// New schema: PK is email (text), not uuid id. full_name renamed to english_name.
export type Analyst = {
  // id field removed - email is the PK
  english_name: string;
  chinese_name: string | null;
  email: string;
  region_code: string | null;
  region: {
    name_en: string;
    name_cn: string;
    code: string;
    is_active: boolean;
  } | null;
  suffix: string | null;
  sfc: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

const PAGE_SIZE = 15;

/**
 * List analysts with pagination and search.
 * No FK on analyst.region_code — region join done in JS.
 */
export async function listAnalysts(params: {
  page: number;
  query: string | null;
}): Promise<Result<PaginatedList<Analyst>>> {
  const supabase = await createServerClient();

  let query = supabase
    .from("analyst")
    .select("*", { count: "exact" });

  if (params.query) {
    const searchTerm = `%${params.query}%`;
    query = query.or(
      `english_name.ilike.${searchTerm},chinese_name.ilike.${searchTerm},email.ilike.${searchTerm}`,
    );
  }

  const from = (params.page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch analysts");

  const total = count ?? 0;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  // JS-side region join
  const regionCodes = [
    ...new Set((data as Analyst[]).map((a) => a.region_code).filter(Boolean)),
  ];
  const { data: regionRows } = regionCodes.length
    ? await supabase.from("region").select("code, name_en, name_cn, is_active").in("code", regionCodes)
    : { data: [] };
  const regionMap: Record<string, { name_en: string; name_cn: string; code: string; is_active: boolean }> = {};
  if (regionRows) {
    for (const r of regionRows) regionMap[r.code] = r;
  }

  const items: Analyst[] = (data as Analyst[]).map((a) => ({
    ...a,
    region: a.region_code ? (regionMap[a.region_code] ?? null) : null,
  }));

  return ok({ items, total, page: params.page, totalPages });
}

/**
 * Create a new analyst. email is the PK (text).
 * No FK on region_code — region fetched separately.
 */
export async function createAnalyst(params: {
  english_name: string;
  chinese_name?: string;
  email: string;
  region_code: string;
  suffix?: string;
  sfc?: string;
}): Promise<Result<Analyst>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("analyst")
    .insert(params)
    .select("*")
    .single();

  if (error) {
    if (error.code === "23505") {
      if (error.message.includes("email")) {
        return err("Email already exists");
      }
    }
    return err(error.message);
  }

  if (!data) return err("Failed to create analyst");

  // Fetch region in JS
  let region: Analyst["region"] = null;
  if (data.region_code) {
    const { data: r } = await supabase
      .from("region")
      .select("code, name_en, name_cn, is_active")
      .eq("code", data.region_code)
      .maybeSingle();
    region = r ?? null;
  }

  return ok({ ...data, region });
}

/**
 * Update an existing analyst. Lookup by email (PK).
 * No FK on region_code — region fetched separately.
 */
export async function updateAnalyst(
  email: string,
  params: {
    english_name?: string;
    chinese_name?: string;
    email?: string;
    region_code?: string;
    suffix?: string;
    sfc?: string;
    is_active?: boolean;
  },
): Promise<Result<Analyst>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("analyst")
    .update(params)
    .eq("email", email)
    .select("*")
    .single();

  if (error) {
    if (error.code === "23505") {
      if (error.message.includes("email")) {
        return err("Email already exists");
      }
    }
    return err(error.message);
  }

  if (!data) return err("Failed to update analyst");

  // Fetch region in JS
  let region: Analyst["region"] = null;
  if (data.region_code) {
    const { data: r } = await supabase
      .from("region")
      .select("code, name_en, name_cn, is_active")
      .eq("code", data.region_code)
      .maybeSingle();
    region = r ?? null;
  }

  return ok({ ...data, region });
}

/**
 * Delete an analyst by email (PK)
 */
export async function deleteAnalyst(email: string): Promise<Result<null>> {
  const supabase = await createServerClient();

  const { error } = await supabase.from("analyst").delete().eq("email", email);

  if (error) return err(error.message);

  return ok(null);
}

/**
 * Get all regions for form dropdown
 */
export async function getRegionsForSelect(): Promise<
  Result<{ id: string; name: string; code: string; name_en: string; name_cn: string }[]>
> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("region")
    .select("code, name_en, name_cn")
    .eq("is_active", true)
    .order("name_en");

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch regions");

  return ok(
    data.map((r) => ({
      id: r.code,
      name: r.name_en,
      code: r.code,
      name_en: r.name_en,
      name_cn: r.name_cn,
    }))
  );
}

/**
 * Get all active analysts for form selector.
 * No FK on region_code — region join done in JS.
 */
export async function listAllActiveAnalysts(): Promise<Result<Analyst[]>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("analyst")
    .select("*")
    .eq("is_active", true)
    .order("english_name", { ascending: true });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch analysts");

  // JS-side region join
  const regionCodes = [
    ...new Set((data as Analyst[]).map((a) => a.region_code).filter(Boolean)),
  ];
  const { data: regionRows } = regionCodes.length
    ? await supabase.from("region").select("code, name_en, name_cn, is_active").in("code", regionCodes)
    : { data: [] };
  const regionMap: Record<string, { name_en: string; name_cn: string; code: string; is_active: boolean }> = {};
  if (regionRows) {
    for (const r of regionRows) regionMap[r.code] = r;
  }

  const items: Analyst[] = (data as Analyst[]).map((a) => ({
    ...a,
    region: a.region_code ? (regionMap[a.region_code] ?? null) : null,
  }));

  return ok(items);
}
