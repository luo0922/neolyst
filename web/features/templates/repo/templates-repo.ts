import "server-only";

import { err, ok, type Result } from "@/lib/result";
import { createServerClient } from "@/lib/supabase/server";

export type Template = {
  id: string;
  name: string;
  report_type: string;
  language: "en" | "zh";
  template_file_path: string;
  schema_file_path: string | null;
  version: number;
  sort: number;
  uploaded_by: string | null;
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
 */
export async function listTemplatesGrouped(): Promise<Result<TemplateGroup[]>> {
  const supabase = await createServerClient();

  // 查询所有模板，按 sort 排序，同 sort 内按 version 倒序
  const { data, error } = await supabase
    .from("template")
    .select("*")
    .order("sort", { ascending: true })
    .order("version", { ascending: false });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch templates");

  // Group by (report_type, language)，每个 group 只取第一条（version 最高）
  const groups = new Map<string, Template[]>();

  for (const row of data as Template[]) {
    const key = `${row.report_type}:${row.language}`;
    if (!groups.has(key)) {
      groups.set(key, [row]);
    }
  }

  // Convert to TemplateGroup format
  const result: TemplateGroup[] = [];

  for (const [key, templates] of groups) {
    const [report_type, language] = key.split(":") as [string, "en" | "zh"];

    result.push({
      report_type,
      language,
      templates,
    });
  }

  // Sort by sort field, then language
  result.sort((a, b) => {
    const sortA = a.templates[0]?.sort ?? 0;
    const sortB = b.templates[0]?.sort ?? 0;
    if (sortA !== sortB) return sortA - sortB;
    return a.language.localeCompare(b.language);
  });

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
    .from("template")
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
    .from("template")
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
    .select("code")
    .eq("is_active", true)
    .order("sort", { ascending: true });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch report types");

  const codes = data.map((item) => item.code).filter((code): code is string => Boolean(code));

  return ok(codes);
}

export async function hasValidTemplateForReportType(
  reportType: string,
  language?: "en" | "zh",
): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  let query = supabase
    .from("template")
    .select("id, template_file_path")
    .eq("report_type", reportType);

  if (language) {
    query = query.eq("language", language);
  }

  const { data, error } = await query;

  if (error) return err(error.message);
  if (!data || data.length === 0) return ok(false);

  return ok(
    data.some((item) => Boolean(item.template_file_path && item.template_file_path.trim().length > 0)),
  );
}

/**
 * Get the latest template for a report_type and language (no activation needed)
 */
export async function getLatestTemplate(
  report_type: ReportType,
  language: "en" | "zh",
): Promise<Result<Template | null>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("template")
    .select("*")
    .eq("report_type", report_type)
    .eq("language", language)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return err(error.message);

  if (!data) return ok(null);
  if (!hasTemplateFile(data as Template)) return ok(null);

  return ok(data as Template);
}

/**
 * Get the next version number for a report_type and language
 */
export async function getNextVersion(
  report_type: ReportType,
  language: "en" | "zh" = "en",
): Promise<number> {
  const supabase = await createServerClient();

  const { data } = await supabase
    .from("template")
    .select("version")
    .eq("report_type", report_type)
    .eq("language", language)
    .order("version", { ascending: false })
    .limit(1)
    .single();

  return (data?.version ?? 0) + 1;
}

/**
 * Create a new template
 */
export async function createTemplate(params: {
  name: string;
  report_type: ReportType;
  language?: "en" | "zh";
  template_file_path: string;
  schema_file_path?: string | null;
  uploaded_by: string;
}): Promise<Result<Template>> {
  const supabase = await createServerClient();
  const language = params.language ?? "en";

  const version = await getNextVersion(params.report_type, language);

  const { data, error } = await supabase
    .from("template")
    .insert({
      name: params.name,
      report_type: params.report_type,
      language,
      template_file_path: params.template_file_path,
      schema_file_path: params.schema_file_path ?? null,
      version,
      uploaded_by: params.uploaded_by,
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
 * Update template metadata (not file)
 */
export async function updateTemplate(
  id: string,
  params: {
    name?: string;
  }
): Promise<Result<Template>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("template")
    .update(params)
    .eq("id", id)
    .select()
    .single();

  if (error) return err(error.message);
  if (!data) return err("Failed to update template");

  return ok(data as Template);
}

/**
 * Update template file for a report_type and language (update existing record, not create new version)
 */
export async function updateTemplateFile(params: {
  report_type: ReportType;
  language: "en" | "zh";
  name?: string;
  template_file_path?: string;
  schema_file_path?: string | null;
  uploaded_by: string;
}): Promise<Result<Template>> {
  const supabase = await createServerClient();

  // Find the existing template for this report_type and language
  const { data: existing, error: findError } = await supabase
    .from("template")
    .select("*")
    .eq("report_type", params.report_type)
    .eq("language", params.language)
    .order("version", { ascending: false })
    .limit(1)
    .single();

  if (findError && findError.code !== "PGRST116") {
    // PGRST116 = no rows returned
    return err(findError.message);
  }

  if (existing) {
    // Update existing record
    const updateData: Record<string, unknown> = {
      uploaded_by: params.uploaded_by,
      updated_at: new Date().toISOString(),
    };

    if (params.name !== undefined) {
      updateData.name = params.name;
    }
    if (params.template_file_path !== undefined) {
      updateData.template_file_path = params.template_file_path;
    }
    if (params.schema_file_path !== undefined) {
      updateData.schema_file_path = params.schema_file_path;
    }

    const { data, error } = await supabase
      .from("template")
      .update(updateData)
      .eq("id", existing.id)
      .select()
      .single();

    if (error) return err(error.message);
    if (!data) return err("Failed to update template");

    return ok(data as Template);
  } else {
    // No existing template, create new one with version 1
    const { data, error } = await supabase
      .from("template")
      .insert({
        name: params.name || `${params.report_type}_template`,
        report_type: params.report_type,
        language: params.language,
        template_file_path: params.template_file_path || "",
        schema_file_path: params.schema_file_path ?? null,
        version: 1,
        uploaded_by: params.uploaded_by,
      })
      .select()
      .single();

    if (error) return err(error.message);
    if (!data) return err("Failed to create template");

    return ok(data as Template);
  }
}

/**
 * Delete a template
 */
export async function deleteTemplate(id: string): Promise<Result<null>> {
  const supabase = await createServerClient();

  const { error } = await supabase.from("template").delete().eq("id", id);

  if (error) return err(error.message);

  return ok(null);
}
