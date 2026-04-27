"use server";

import { revalidatePath } from "next/cache";

import { templateSchema, templateUpdateSchema } from "@/domain/schemas/template";
import { err, ok, type Result } from "@/lib/result";
import { requireAdmin, createServiceRoleClient } from "@/lib/supabase/server";

type StorageUploadResult =
  | { ok: true; file_path: string }
  | { ok: false; error: string };

import {
  createTemplate as createTemplateRepo,
  deleteTemplate as deleteTemplateRepo,
  getTemplate as getTemplateRepo,
  listTemplates as listTemplatesRepo,
  listTemplatesGrouped as listTemplatesGroupedRepo,
  listTemplateReportTypes as listTemplateReportTypesRepo,
  updateTemplate as updateTemplateRepo,
  type Template,
  type TemplateGroup,
  type ReportType,
} from "./repo/templates-repo";

async function requireAdminOrThrow() {
  await requireAdmin();
}

/**
 * List all templates grouped by report_type and language
 */
export async function listTemplatesGroupedAction(): Promise<
  Result<TemplateGroup[]>
> {
  await requireAdminOrThrow();

  try {
    return await listTemplatesGroupedRepo();
  } catch {
    return err("Failed to list templates.");
  }
}

/**
 * List templates with optional filters
 */
export async function listTemplatesAction(params?: {
  report_type?: ReportType;
}): Promise<Result<Template[]>> {
  await requireAdminOrThrow();

  try {
    return await listTemplatesRepo(params);
  } catch {
    return err("Failed to list templates.");
  }
}

/**
 * List all distinct report types from report_type table
 */
export async function listTemplateReportTypesAction(): Promise<Result<string[]>> {
  try {
    return await listTemplateReportTypesRepo();
  } catch {
    return err("Failed to list report types.");
  }
}

/**
 * Get a single template
 */
export async function getTemplateAction(id: string): Promise<Result<Template>> {
  await requireAdminOrThrow();

  try {
    return await getTemplateRepo(id);
  } catch {
    return err("Failed to get template.");
  }
}

/**
 * Create a new template record.
 * id is auto-generated as ${report_type}_${language}
 * No name/version/uploaded_by fields in new schema.
 */
export async function createTemplateAction(input: {
  report_type: ReportType;
  language?: "en" | "zh";
  template_file_path: string;
  schema_file_path?: string | null;
}): Promise<Result<Template>> {
  await requireAdminOrThrow();

  const parsed = templateSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const result = await createTemplateRepo({
    report_type: input.report_type,
    language: input.language,
    template_file_path: input.template_file_path,
    schema_file_path: input.schema_file_path ?? null,
  });

  if (result.ok) {
    revalidatePath("/templates");
  }
  return result;
}

/**
 * Update template (no-op in new schema - file paths updated via upload)
 */
export async function updateTemplateAction(
  id: string,
  input: unknown,
): Promise<Result<Template>> {
  await requireAdminOrThrow();

  const parsed = templateUpdateSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const updateResult = await updateTemplateRepo(id, parsed.data);

  if (updateResult.ok) {
    revalidatePath("/templates");
  }
  return updateResult;
}

/**
 * Delete a template
 */
export async function deleteTemplateAction(id: string): Promise<Result<null>> {
  await requireAdminOrThrow();

  const result = await deleteTemplateRepo(id);
  if (!result.ok) {
    return result;
  }
  revalidatePath("/templates");
  return ok(null);
}

export async function uploadTemplateFileAction(
  formData: FormData,
): Promise<StorageUploadResult> {
  await requireAdminOrThrow();

  const file = formData.get("file") as File | null;
  const reportType = formData.get("reportType") as string | null;
  const fileKind = formData.get("fileKind") as string | null; // "template" or "schema"

  if (!file || !reportType || !fileKind) {
    return { ok: false, error: "Missing required fields." };
  }

  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filePath = `${reportType}/${fileKind}/${timestamp}_${safeName}`;

  const supabase = createServiceRoleClient();
  const arrayBuffer = await file.arrayBuffer();

  const { error } = await supabase.storage
    .from("templates")
    .upload(filePath, arrayBuffer, {
      contentType: file.type,
      upsert: false,
    });

  if (error) {
    return { ok: false, error: error.message };
  }

  return { ok: true, file_path: filePath };
}
