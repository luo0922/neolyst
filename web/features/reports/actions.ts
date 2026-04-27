"use server";

import { revalidatePath } from "next/cache";

import {
  reportCreateSchema,
  reportDirectSubmitSchema,
  reportDownloadSchema,
  reportSaveSchema,
  reportSubmitSchema,
  type ReportAnalystInput,
  type ReportLanguage,
  type ReportStatus,
} from "@/domain/schemas/report";
import { listAllActiveAnalysts } from "@/features/analyst-info/repo/analysts-repo";
import { err, type Result } from "@/lib/result";
import { createServiceRoleClient, requireAuth } from "@/lib/supabase/server";

import {
  createReport,
  findCoverageByTicker,
  getReportDetail,
  getReportDownloadUrl,
  hasValidTemplateForReportType,
  listReportTypeOptions,
  listReports,
  reportTypeExists,
  regionCodeExists,
  saveReportContent,
  sectorExists,
  submitReport,
  type ReportDetail,
} from "./repo/reports-repo";

type Role = "admin" | "sa" | "analyst";

async function getActor(): Promise<
  Result<{ user: Awaited<ReturnType<typeof requireAuth>>; role: Role }>
> {
  try {
    const user = await requireAuth();
    const role = user.app_metadata?.role as Role | undefined;
    if (role !== "admin" && role !== "sa" && role !== "analyst") {
      return err("No permission");
    }
    return { ok: true, data: { user, role } };
  } catch {
    return err("Unauthorized");
  }
}

function canCreateOrEdit(role: Role): boolean {
  return role === "admin" || role === "analyst";
}

function isEditableStatus(status: ReportStatus): boolean {
  return status === "draft" || status === "submitted";
}

function trimToNull(value?: string | number | null): string | null {
  if (!value) {
    return null;
  }
  const strValue = String(value);
  const trimmed = strValue.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function resolveOptionalText(
  input: string | null | undefined,
  fallback: string | null | undefined,
): string | null {
  if (input === undefined) {
    return fallback ?? null;
  }
  return trimToNull(input);
}

function resolveOptionalId(
  input: string | null | undefined,
  fallback: string | null | undefined,
): string | null {
  if (input === undefined) {
    return fallback ?? null;
  }
  if (input === "" || input === null) {
    return null;
  }
  return input;
}

function isCompanyType(reportType: string): boolean {
  return reportType === "company" || reportType === "company_flash";
}

function requiresRegion(reportType: string): boolean {
  return (
    reportType === "sector" ||
    reportType === "sector_flash" ||
    reportType === "common"
  );
}

function requiresSector(reportType: string): boolean {
  return reportType === "sector" || reportType === "sector_flash";
}

function requiresModel(reportType: string): boolean {
  return reportType === "company";
}

/**
 * Validate analysts: check that all analyst_email values exist in active analyst list.
 * New schema: analyst_email (text) instead of analyst_id (uuid)
 */
async function validateAnalysts(
  input: { analyst_email: string }[],
): Promise<string | null> {
  if (input.length === 0) {
    return null;
  }

  const analystsResult = await listAllActiveAnalysts();
  if (!analystsResult.ok) {
    return "Failed to validate analyst list.";
  }

  const activeEmails = new Set(
    analystsResult.data.map((item) => item.email.toLowerCase()),
  );
  const hasInvalid = input.some(
    (item) => !activeEmails.has(item.analyst_email.toLowerCase()),
  );
  if (hasInvalid) {
    return "Analyst must be selected from the active analyst list.";
  }

  return null;
}

async function validateSourceTables(input: {
  report_type: string;
  region_code?: string | null;
  sector_id?: string | null;
}): Promise<string | null> {
  const reportTypeCheck = await reportTypeExists(input.report_type);
  if (!reportTypeCheck.ok) {
    return "Failed to validate report type.";
  }
  if (!reportTypeCheck.data) {
    return "Report Type must be a valid active type.";
  }

  if (input.region_code) {
    const regionCheck = await regionCodeExists(input.region_code);
    if (!regionCheck.ok) {
      return "Failed to validate region.";
    }
    if (!regionCheck.data) {
      return "Region must be selected from the valid region list.";
    }
  }

  if (input.sector_id) {
    const sectorCheck = await sectorExists(input.sector_id);
    if (!sectorCheck.ok) {
      return "Failed to validate sector.";
    }
    if (!sectorCheck.data) {
      return "Sector must be selected from the valid sector list.";
    }
  }

  return null;
}

async function resolveCoverageIdForDraft(input: {
  report_type: string;
  ticker?: string | null;
}): Promise<Result<string | null>> {
  if (!isCompanyType(input.report_type)) {
    return { ok: true, data: null };
  }

  const ticker = trimToNull(input.ticker);
  if (!ticker) {
    return { ok: true, data: null };
  }

  const coverageResult = await findCoverageByTicker(ticker);
  if (!coverageResult.ok) {
    return err("Failed to validate coverage.");
  }

  return { ok: true, data: coverageResult.data?.id ?? null };
}

/**
 * Validate report before submit.
 * New schema: word_path/pdf_path/model_path directly on report (no version).
 * certificate_confirmed removed.
 */
async function validateReportForSubmit(
  detail: ReportDetail,
): Promise<string | null> {
  const sourceCheck = await validateSourceTables({
    report_type: detail.report_type,
    region_code: detail.region_code,
    sector_id: detail.sector_id,
  });
  if (sourceCheck) {
    return sourceCheck;
  }

  const templateCheck = await hasValidTemplateForReportType(detail.report_type);
  if (!templateCheck.ok) {
    return "Failed to validate template availability.";
  }
  if (!templateCheck.data) {
    return "No valid template found for selected Report Type.";
  }

  if (!trimToNull(detail.title)) {
    return "Report title is required.";
  }
  if (!detail.report_language) {
    return "Report language is required.";
  }
  if (!trimToNull(detail.investment_thesis)) {
    return "Investment thesis (report abstract) is required.";
  }
  if (detail.analysts.length === 0) {
    return "At least one Analyst is required.";
  }
  // certificate_confirmed check removed

  if (requiresRegion(detail.report_type) && !detail.region_code) {
    return "Region is required for this Report Type.";
  }
  if (requiresSector(detail.report_type) && !detail.sector_id) {
    return "Sector is required for this Report Type.";
  }

  if (detail.report_type === "company") {
    if (!trimToNull(detail.ticker)) {
      return "Ticker is required for Company report.";
    }
    if (!trimToNull(detail.rating)) {
      return "Rating is required for Company report.";
    }
    if (!trimToNull(detail.target_price)) {
      return "Target price is required for Company report.";
    }
  }

  if (detail.report_type === "company_flash" && !trimToNull(detail.ticker)) {
    return "Ticker is required for Company Flash report.";
  }

  // File paths now directly on report (not in latest_version)
  if (!detail.word_path) {
    return "Report Word file is required before submit.";
  }

  if (requiresModel(detail.report_type) && !detail.model_path) {
    return "Company report requires Model file before submit.";
  }

  if (isCompanyType(detail.report_type)) {
    const ticker = trimToNull(detail.ticker);
    if (!ticker) {
      return "Ticker is required for company-type reports.";
    }
    const coverageResult = await findCoverageByTicker(ticker);
    if (!coverageResult.ok) {
      return "Failed to validate Coverage relation.";
    }
    if (!coverageResult.data) {
      return "Company-type reports require a valid Coverage. Please complete Coverage maintenance first.";
    }
    if (coverageResult.data.analyst_emails.length === 0) {
      return "Matched Coverage has no Analyst mapping. Please maintain Coverage first.";
    }
    const reportAnalystEmails = new Set(
      detail.analysts.map((item) => item.analyst_email.toLowerCase()),
    );
    const overlap = coverageResult.data.analyst_emails.some((email) =>
      reportAnalystEmails.has(email.toLowerCase()),
    );
    if (!overlap) {
      return "Company-type submit requires Coverage relation with matching Analyst assignment.";
    }
  }

  return null;
}

async function assertEditable(
  role: Role,
  userId: string,
  reportId: string,
): Promise<Result<ReportDetail>> {
  const detailResult = await getReportDetail(reportId);
  if (!detailResult.ok) {
    return detailResult;
  }

  const detail = detailResult.data;
  if (!isEditableStatus(detail.status)) {
    return err("Only draft/submitted reports can be edited.");
  }

  if (role === "analyst" && detail.owner_user_id !== userId) {
    return err("No permission");
  }

  return detailResult;
}

/**
 * Build save payload from input + fallback.
 * New schema: contact_person (email), no certificate_confirmed, direct file paths.
 */
function toSavePayload(input: {
  title: string;
  report_type: string;
  ticker?: string | null;
  rating?: string | null;
  target_price?: string | null;
  region_code?: string | null;
  sector_id?: string | null;
  report_language?: ReportLanguage | null;
  contact_person?: string | null;
  investment_thesis?: string | null;
  coverage_id?: string | null;
  analysts: ReportAnalystInput[];
  word_path?: string | null;
  pdf_path?: string | null;
  model_path?: string | null;
  fallback?: Partial<ReportDetail>;
}) {
  return {
    title: input.title.trim(),
    report_type: input.report_type.trim(),
    ticker: resolveOptionalText(input.ticker, input.fallback?.ticker),
    rating: resolveOptionalText(input.rating, input.fallback?.rating),
    target_price: resolveOptionalText(
      input.target_price,
      input.fallback?.target_price,
    ),
    region_code: resolveOptionalId(input.region_code, input.fallback?.region_code),
    sector_id: resolveOptionalId(input.sector_id, input.fallback?.sector_id),
    report_language:
      input.report_language === undefined
        ? (input.fallback?.report_language ?? null)
        : (input.report_language ?? null),
    // contact_person is now analyst email (text), not uuid user id
    contact_person: resolveOptionalId(
      input.contact_person,
      input.fallback?.contact_person,
    ),
    investment_thesis: resolveOptionalText(
      input.investment_thesis,
      input.fallback?.investment_thesis,
    ),
    coverage_id: resolveOptionalId(
      input.coverage_id,
      input.fallback?.coverage_id,
    ),
    analysts: input.analysts,
    // File paths directly on report
    word_path:
      input.word_path === undefined
        ? (input.fallback?.word_path ?? null)
        : (input.word_path ?? null),
    pdf_path:
      input.pdf_path === undefined
        ? (input.fallback?.pdf_path ?? null)
        : (input.pdf_path ?? null),
    model_path:
      input.model_path === undefined
        ? (input.fallback?.model_path ?? null)
        : (input.model_path ?? null),
  };
}

export async function listReportTypeOptionsAction(): Promise<Result<string[]>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }
  return listReportTypeOptions();
}

export async function listReportsAction(input: {
  page?: number;
  query?: string | null;
  status?: ReportStatus | null;
}): Promise<
  Result<{
    items: Awaited<ReturnType<typeof listReports>> extends Result<infer T>
      ? T extends { items: infer U }
        ? U
        : never
      : never;
    total: number;
    page: number;
    totalPages: number;
    applied_status: ReportStatus | null;
  }>
> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const page = Math.max(1, input.page ?? 1);
  const query = input.query ?? null;
  const defaultStatus = null;
  const appliedStatus = input.status ?? defaultStatus;

  const listResult = await listReports({
    page,
    query,
    status: appliedStatus,
  });

  if (!listResult.ok) {
    return listResult;
  }

  return {
    ok: true,
    data: {
      ...listResult.data,
      applied_status: appliedStatus,
    },
  };
}

export async function getReportDetailAction(
  reportId: string,
): Promise<Result<ReportDetail>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }
  return getReportDetail(reportId);
}

export async function createReportAction(
  input: unknown,
): Promise<Result<ReportDetail>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const { role, user } = actor.data;
  if (!canCreateOrEdit(role)) {
    return err("No permission");
  }

  const parsed = reportCreateSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const analystError = await validateAnalysts(parsed.data.analysts);
  if (analystError) {
    return err(analystError);
  }

  const sourceCheck = await validateSourceTables({
    report_type: parsed.data.report_type,
    region_code: parsed.data.region_code,
    sector_id: parsed.data.sector_id,
  });
  if (sourceCheck) {
    return err(sourceCheck);
  }

  const coverageIdResult = await resolveCoverageIdForDraft({
    report_type: parsed.data.report_type,
    ticker: parsed.data.ticker,
  });
  if (!coverageIdResult.ok) {
    return coverageIdResult;
  }

  const payload = toSavePayload({
    ...parsed.data,
    coverage_id: coverageIdResult.data,
  });

  const createResult = await createReport({
    report_id: crypto.randomUUID(),
    owner_user_id: user.id,
    title: payload.title,
    report_type: payload.report_type,
    ticker: payload.ticker,
    rating: payload.rating,
    target_price: payload.target_price,
    region_code: payload.region_code,
    coverage_id: payload.coverage_id,
    sector_id: payload.sector_id,
    report_language: payload.report_language,
    contact_person: payload.contact_person,
    investment_thesis: payload.investment_thesis,
    analysts: payload.analysts,
  });

  if (createResult.ok) {
    revalidatePath("/reports");
    revalidatePath("/report-review");
    revalidatePath("/reports/new");
  }

  return createResult;
}

export async function saveReportContentAction(
  input: unknown,
): Promise<Result<ReportDetail>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const { role, user } = actor.data;
  if (!canCreateOrEdit(role)) {
    return err("No permission");
  }

  const parsed = reportSaveSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const editableResult = await assertEditable(
    role,
    user.id,
    parsed.data.report_id,
  );
  if (!editableResult.ok) {
    return editableResult;
  }

  const analystError = await validateAnalysts(parsed.data.analysts);
  if (analystError) {
    return err(analystError);
  }

  const sourceCheck = await validateSourceTables({
    report_type: parsed.data.report_type,
    region_code: parsed.data.region_code,
    sector_id: parsed.data.sector_id,
  });
  if (sourceCheck) {
    return err(sourceCheck);
  }

  const coverageIdResult = await resolveCoverageIdForDraft({
    report_type: parsed.data.report_type,
    ticker: parsed.data.ticker,
  });
  if (!coverageIdResult.ok) {
    return coverageIdResult;
  }

  const payload = toSavePayload({
    ...parsed.data,
    coverage_id: coverageIdResult.data,
    fallback: editableResult.data,
  });

  const saveResult = await saveReportContent({
    report_id: parsed.data.report_id,
    changed_by: user.id,
    title: payload.title,
    report_type: payload.report_type,
    ticker: payload.ticker,
    rating: payload.rating,
    target_price: payload.target_price,
    region_code: payload.region_code,
    sector_id: payload.sector_id,
    report_language: payload.report_language,
    contact_person: payload.contact_person,
    investment_thesis: payload.investment_thesis,
    coverage_id: payload.coverage_id,
    analysts: payload.analysts,
    word_path: payload.word_path,
    pdf_path: payload.pdf_path,
    model_path: payload.model_path,
  });

  if (saveResult.ok) {
    revalidatePath("/reports");
    revalidatePath("/report-review");
    revalidatePath("/reports/new");
  }

  return saveResult;
}

export async function submitReportAction(
  input: unknown,
): Promise<Result<ReportDetail>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const { role, user } = actor.data;
  if (!canCreateOrEdit(role)) {
    return err("No permission");
  }

  const parsed = reportSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const detailResult = await getReportDetail(parsed.data.report_id);
  if (!detailResult.ok) {
    return detailResult;
  }

  const detail = detailResult.data;
  if (detail.status !== "draft") {
    return err("Only draft reports can be submitted.");
  }

  if (role === "analyst" && detail.owner_user_id !== user.id) {
    return err("No permission");
  }

  const submitValidationError = await validateReportForSubmit(detail);
  if (submitValidationError) {
    return err(submitValidationError);
  }

  const submitResult = await submitReport(parsed.data.report_id);

  if (submitResult.ok) {
    revalidatePath("/reports");
    revalidatePath("/report-review");
    revalidatePath("/reports/new");
  }

  return submitResult;
}

export async function directSubmitReportAction(
  input: unknown,
): Promise<Result<ReportDetail>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const { role, user } = actor.data;
  if (!canCreateOrEdit(role)) {
    return err("No permission");
  }

  const parsed = reportDirectSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const analystError = await validateAnalysts(parsed.data.analysts);
  if (analystError) {
    return err(analystError);
  }

  const sourceCheck = await validateSourceTables({
    report_type: parsed.data.report_type,
    region_code: parsed.data.region_code,
    sector_id: parsed.data.sector_id,
  });
  if (sourceCheck) {
    return err(sourceCheck);
  }

  const coverageIdResult = await resolveCoverageIdForDraft({
    report_type: parsed.data.report_type,
    ticker: parsed.data.ticker,
  });
  if (!coverageIdResult.ok) {
    return coverageIdResult;
  }

  const payload = toSavePayload({
    ...parsed.data,
    coverage_id: coverageIdResult.data,
  });

  let reportId = parsed.data.report_id;

  if (!reportId) {
    reportId = crypto.randomUUID();
    const createResult = await createReport({
      report_id: reportId,
      owner_user_id: user.id,
      title: payload.title,
      report_type: payload.report_type,
      ticker: payload.ticker,
      rating: payload.rating,
      target_price: payload.target_price,
      region_code: payload.region_code,
      coverage_id: payload.coverage_id,
      sector_id: payload.sector_id,
      report_language: payload.report_language,
      contact_person: payload.contact_person,
      investment_thesis: payload.investment_thesis,
      analysts: payload.analysts,
    });

    if (!createResult.ok) {
      return createResult;
    }
  } else {
    const editableResult = await assertEditable(role, user.id, reportId);
    if (!editableResult.ok) {
      return editableResult;
    }

    if (editableResult.data.status !== "draft") {
      return err("Direct submit only supports draft reports.");
    }

    const saveResult = await saveReportContent({
      report_id: reportId,
      changed_by: user.id,
      title: payload.title,
      report_type: payload.report_type,
      ticker: payload.ticker,
      rating: payload.rating,
      target_price: payload.target_price,
      region_code: payload.region_code,
      sector_id: payload.sector_id,
      report_language: payload.report_language,
      contact_person: payload.contact_person,
      investment_thesis: payload.investment_thesis,
      coverage_id: payload.coverage_id,
      analysts: payload.analysts,
      word_path: payload.word_path,
      pdf_path: payload.pdf_path,
      model_path: payload.model_path,
    });

    if (!saveResult.ok) {
      return saveResult;
    }

    const submitValidationError = await validateReportForSubmit(saveResult.data);
    if (submitValidationError) {
      return err(`已保存为 Draft，提交失败：${submitValidationError}`);
    }

    const submitResult = await submitReport(reportId);
    if (!submitResult.ok) {
      return err("已保存为 Draft，提交失败");
    }

    revalidatePath("/reports");
    revalidatePath("/report-review");
    revalidatePath("/reports/new");
    return submitResult;
  }

  const submitValidationError = await validateReportForSubmit({
    ...payload,
    id: reportId,
    owner_user_id: user.id,
    status: "draft" as ReportStatus,
    analysts: payload.analysts,
    lead_analyst_email: "",
    analyst_emails: [],
    created_at: "",
    updated_at: "",
  } as unknown as ReportDetail);
  if (submitValidationError) {
    return err(`已保存为 Draft，提交失败：${submitValidationError}`);
  }

  const submitResult = await submitReport(reportId);
  if (!submitResult.ok) {
    return err("已保存为 Draft，提交失败");
  }

  revalidatePath("/reports");
  revalidatePath("/report-review");
  revalidatePath("/reports/new");
  return submitResult;
}

export async function getReportDownloadUrlAction(
  input: unknown,
): Promise<Result<string>> {
  const actor = await getActor();
  if (!actor.ok) {
    return actor;
  }

  const parsed = reportDownloadSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  return getReportDownloadUrl(parsed.data);
}

export type StorageUploadResult =
  | { ok: true; file_path: string }
  | { ok: false; error: string };

/**
 * Upload report file to storage.
 * New schema: no version numbers. Path format: reports/{reportId}/{category}/{timestamp}_{filename}
 * chief-approval label removed.
 */
export async function uploadReportFileAction(
  formData: FormData,
): Promise<StorageUploadResult> {
  const actor = await getActor();
  if (!actor.ok) {
    return { ok: false, error: "Unauthorized" };
  }
  if (!canCreateOrEdit(actor.data.role)) {
    return { ok: false, error: "No permission" };
  }

  const file = formData.get("file") as File | null;
  const reportId = formData.get("reportId") as string | null;
  const label = formData.get("label") as string;
  const bucket = (formData.get("bucket") as string | null) ?? "reports";

  if (!file || !reportId || !label) {
    return { ok: false, error: "Missing required fields." };
  }

  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");

  // Path format: reports/{reportId}/{label}/{timestamp}_{filename}
  // Valid labels: "report", "report-pdf", "model"
  const filePath = `reports/${reportId}/${label}/${timestamp}_${safeName}`;

  const supabase = createServiceRoleClient();
  const arrayBuffer = await file.arrayBuffer();

  const { error } = await supabase.storage
    .from(bucket)
    .upload(filePath, arrayBuffer, {
      contentType: file.type,
      upsert: true,
    });

  if (error) {
    return { ok: false, error: error.message };
  }

  return { ok: true, file_path: filePath };
}
