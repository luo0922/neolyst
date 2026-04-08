"use server";

import { revalidatePath } from "next/cache";

import {
  templateSchema,
  templateUpdateSchema,
} from "@/domain/schemas/template";
import { err, ok, type Result } from "@/lib/result";
import { requireAdmin, getCurrentUser, createServiceRoleClient } from "@/lib/supabase/server";
import { updateTemplate } from "./repo/templates-repo";

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
  updateTemplateFile as updateTemplateFileRepo,
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
 * List all distinct report types from template table
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
 * Create a new template version
 */
export async function createTemplateAction(input: {
  name: string;
  report_type: ReportType;
  language?: "en" | "zh";
  template_file_path: string;
  schema_file_path?: string | null;
}): Promise<Result<Template>> {
  await requireAdminOrThrow();

  const user = await getCurrentUser();
  if (!user) {
    return err("Unauthorized");
  }

  const parsed = templateSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const result = await createTemplateRepo({
    ...parsed.data,
    language: input.language,
    template_file_path: input.template_file_path,
    schema_file_path: input.schema_file_path ?? null,
    uploaded_by: user.id,
  });

  if (result.ok) {
    revalidatePath("/templates");
  }
  return result;
}

/**
 * Update template file for existing template (update current version, not create new)
 */
export async function updateTemplateFileAction(input: {
  name?: string;
  report_type: ReportType;
  language?: "en" | "zh";
  template_file_path?: string;
  schema_file_path?: string | null;
}): Promise<Result<Template>> {
  await requireAdminOrThrow();

  const user = await getCurrentUser();
  if (!user) {
    return err("Unauthorized");
  }

  const result = await updateTemplateFileRepo({
    report_type: input.report_type,
    language: input.language ?? "en",
    name: input.name,
    template_file_path: input.template_file_path,
    schema_file_path: input.schema_file_path,
    uploaded_by: user.id,
  });

  if (result.ok) {
    revalidatePath("/templates");
  }
  return result;
}

/**
 * Update template metadata
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

  const updateResult = await updateTemplate(id, { name: parsed.data.name });

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
