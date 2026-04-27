import "server-only";

import { err, ok, type Result } from "@/lib/result";
import { createServerClient } from "@/lib/supabase/server";

// New schema: table is now report_template, PK is text id = "${report_type}_${language}"
// Removed: version, sort, uploaded_by, name
export type Template = {
  id: string; // now: report_type_language format e.g., "company_en"
  report_type: string;
  language: "en" | "zh";
  template_file_path: string;
  schema_file_path: string | null;
  created_at: string;
  updated_at: string;
};

export type TemplateGroup = {
  report_type: string;
  language: "en" | "zh";
  templates: Template[];
};

export type ReportType =
  | "company"
  | "sector"
  | "company_flash"
  | "sector_flash"
  | "macro"
  | "strategy"
  | "quantitative"
  | "bond";
export type Language = "en" | "zh";

function hasTemplateFile(template: Pick<Template, "template_file_path">): boolean {
  return template.template_file_path.trim().length > 0;
}

/**
 * List all templates grouped by report_type and language
 * Each (report_type, language) pair has exactly one row (no versioning)
 */
export async function listTemplatesGrouped(): Promise<Result<TemplateGroup[]>> {
  const supabase = await createServerClient();

  // New schema: report_template table, no version/sort columns
  const { data, error } = await supabase
    .from("report_template")
    .select("*")
    .order("report_type", { ascending: true })
    .order("language", { ascending: true });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch templates");

  // Group by (report_type, language) - each group has at most 1 row in new schema
  const groups = new Map<string, Template[]>();

  for (const row of data as Template[]) {
    const key = `${row.report_type}:${row.language}`;
    if (!groups.has(key)) {
      groups.set(key, [row]);
    }
  }

  const result: TemplateGroup[] = [];

  for (const [key, templates] of groups) {
    const [report_type, language] = key.split(":") as [string, "en" | "zh"];

    result.push({
      report_type,
      language,
      templates,
    });
  }

  // Sort by report_type
  result.sort((a, b) => a.report_type.localeCompare(b.report_type));

  return ok(result);
}

/**
 * List templates with optional filters
 */
export async function listTemplates(params?: {
  report_type?: ReportType;
}): Promise<Result<Template[]>> {
  const supabase = await createServerClient();

  let query = supabase
    .from("report_template")
    .select("*")
    .order("created_at", { ascending: false });

  if (params?.report_type) {
    query = query.eq("report_type", params.report_type);
  }

  const { data, error } = await query;

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch templates");

  return ok(data as Template[]);
}

/**
 * Get a single template by ID
 */
export async function getTemplate(id: string): Promise<Result<Template>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_template")
    .select("*")
    .eq("id", id)
    .single();

  if (error) return err(error.message);
  if (!data) return err("Template not found");

  return ok(data as Template);
}

export async function listTemplateReportTypes(): Promise<Result<string[]>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_type")
    .select("report_type")
    .eq("is_active", true)
    .order("sort", { ascending: true });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch report types");

  const codes = data
    .map((item) => item.report_type as string)
    .filter((code): code is string => Boolean(code));

  return ok(codes);
}

export async function hasValidTemplateForReportType(
  reportType: string,
  language?: "en" | "zh",
): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  let query = supabase
    .from("report_template")
    .select("id, template_file_path")
    .eq("report_type", reportType);

  if (language) {
    query = query.eq("language", language);
  }

  const { data, error } = await query;

  if (error) return err(error.message);
  if (!data || data.length === 0) return ok(false);

  return ok(
    data.some(
      (item) =>
        item.template_file_path && item.template_file_path.trim().length > 0,
    ),
  );
}

/**
 * Get the template for a report_type and language
 * No versioning - returns the single row if it exists and has a file
 */
export async function getLatestTemplate(
  report_type: ReportType,
  language: "en" | "zh",
): Promise<Result<Template | null>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_template")
    .select("*")
    .eq("report_type", report_type)
    .eq("language", language)
    .maybeSingle();

  if (error) return err(error.message);

  if (!data) return ok(null);
  if (!hasTemplateFile(data as Template)) return ok(null);

  return ok(data as Template);
}

/**
 * Create a new template record.
 * id is auto-generated as ${report_type}_${language} on the server side (via upsert_template_record RPC)
 * or directly here by constructing the id.
 */
export async function createTemplate(params: {
  report_type: ReportType;
  language?: "en" | "zh";
  template_file_path: string;
  schema_file_path?: string | null;
}): Promise<Result<Template>> {
  const supabase = await createServerClient();
  const language = params.language ?? "en";
  const id = `${params.report_type}_${language}`;

  const { data, error } = await supabase
    .from("report_template")
    .insert({
      id,
      report_type: params.report_type,
      language,
      template_file_path: params.template_file_path,
      schema_file_path: params.schema_file_path ?? null,
    })
    .select()
    .single();

  if (error) {
    return err(error.message);
  }

  if (!data) return err("Failed to create template");

  return ok(data as Template);
}

/**
 * Update template file paths (server updates template_file_path and schema_file_path)
 * No name/version fields in new schema
 */
export async function updateTemplate(
  id: string,
  _params: Record<string, never>,
): Promise<Result<Template>> {
  // In the new schema, there are no updateable fields other than file paths
  // which are updated via upload + upsert_template_record RPC
  // This function is kept for API compatibility but does nothing
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_template")
    .select("*")
    .eq("id", id)
    .single();

  if (error) return err(error.message);
  if (!data) return err("Template not found");

  return ok(data as Template);
}

/**
 * Delete a template
 */
export async function deleteTemplate(id: string): Promise<Result<null>> {
  const supabase = await createServerClient();

  const { error } = await supabase
    .from("report_template")
    .delete()
    .eq("id", id);

  if (error) return err(error.message);

  return ok(null);
}
