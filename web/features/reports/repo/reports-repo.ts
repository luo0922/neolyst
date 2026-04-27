import "server-only";

import type {
  ReportAnalystInput,
  ReportLanguage,
  ReportStatus,
  ReportType,
} from "@/domain/schemas/report";
import { err, ok, type Result } from "@/lib/result";
import type { PaginatedList } from "@/lib/pagination";
import { createServerClient } from "@/lib/supabase/server";

const PAGE_SIZE = 15;

// New schema: analysts stored as text[] (analyst_emails) directly on report
// No more ReportAnalyst junction table, no ReportVersion, no ChiefApprove
export type ReportAnalystEmail = {
  analyst_email: string;
  english_name: string | null;
  chinese_name: string | null;
  author_order: number;
};

// ReportStatusLog: no version_no, file paths now in metadata JSONB
export type ReportStatusLog = {
  id: string;
  report_id: string;
  from_status: ReportStatus;
  to_status: ReportStatus;
  action_by: string;
  action_by_name: string | null;
  action_at: string;
  reason: string | null;
  created_at: string;
  metadata: Record<string, unknown>;
};

export type ReportSummary = {
  id: string;
  owner_user_id: string;
  owner_name: string | null;
  title: string;
  report_type: ReportType;
  ticker: string | null;
  rating: string | null;
  target_price: string | null;
  region_code: string | null;
  report_language: ReportLanguage | null;
  // contact_person is now analyst.email (text), not user uuid
  contact_person: string | null;
  contact_person_name: string | null;
  investment_thesis: string | null;
  // certificate_confirmed removed
  status: ReportStatus;
  // current_version_no removed
  // File paths now directly on report
  word_path: string | null;
  pdf_path: string | null;
  model_path: string | null;
  // published_by/published_at added
  published_by: string | null;
  published_at: string | null;
  // rejection_reason added
  rejection_reason: string | null;
  coverage_id: string | null;
  sector_id: string | null;
  // analyst_emails text[] and lead_analyst_email
  lead_analyst_email: string;
  analyst_emails: string[];
  created_at: string;
  updated_at: string;
  analysts: ReportAnalystEmail[];
};

export type ReportDetail = ReportSummary & {
  coverage?: {
    id: string;
    ticker: string;
    english_name: string;
  } | null;
  region?: {
    id: string;
    name_en: string;
    name_cn: string;
    code: string;
    is_active: boolean;
  } | null;
  sector?: {
    id: string;
    name_en: string;
    name_cn: string | null;
  } | null;
  // chief_approve removed
  // versions/latest_version removed
  status_logs: ReportStatusLog[];
};

export type CoverageMatch = {
  id: string;
  ticker: string;
  analyst_emails: string[];
};

export type CreateReportParams = {
  report_id?: string;
  owner_user_id: string;
  title: string;
  report_type: ReportType;
  ticker?: string | null;
  rating?: string | null;
  target_price?: string | null;
  region_code?: string | null;
  coverage_id?: string | null;
  sector_id?: string | null;
  report_language?: ReportLanguage | null;
  contact_person?: string | null;
  investment_thesis?: string | null;
  analysts: ReportAnalystInput[];
};

export type SaveReportContentParams = {
  report_id: string;
  title: string;
  report_type: ReportType;
  ticker?: string | null;
  rating?: string | null;
  target_price?: string | null;
  region_code?: string | null;
  coverage_id?: string | null;
  sector_id?: string | null;
  report_language?: ReportLanguage | null;
  contact_person?: string | null;
  investment_thesis?: string | null;
  analysts: ReportAnalystInput[];
  changed_by: string;
  word_path?: string | null;
  pdf_path?: string | null;
  model_path?: string | null;
};

export type ListReportsParams = {
  page: number;
  query: string | null;
  status: "all" | ReportStatus | null;
};


function normalizeReportSummaryRow(
  row: Record<string, unknown>,
  allAnalystMap: Record<string, Record<string, unknown>>,
): ReportSummary {
  const ownerName = (row.owner_name as string | undefined) ?? null;
  const contactPersonName = (row.contact_person_name as string | undefined) ?? null;
  const analystEmails = (row.analyst_emails as string[] | undefined) ?? [];

  const analysts: ReportAnalystEmail[] = analystEmails.map((email, idx) => {
    const info = allAnalystMap[email.toLowerCase()];
    return {
      analyst_email: email,
      english_name: (info?.english_name as string | null) ?? null,
      chinese_name: (info?.chinese_name as string | null) ?? null,
      author_order: idx + 1,
    };
  });

  return {
    id: row.id as string,
    owner_user_id: row.owner_user_id as string,
    owner_name: ownerName,
    title: row.title as string,
    report_type: row.report_type as ReportType,
    ticker: row.ticker as string | null,
    rating: row.rating as string | null,
    target_price: row.target_price != null ? String(row.target_price) : null,
    region_code: row.region_code as string | null,
    report_language: row.report_language as ReportLanguage | null,
    contact_person: row.contact_person as string | null,
    contact_person_name: contactPersonName,
    investment_thesis: row.investment_thesis as string | null,
    status: row.status as ReportStatus,
    word_path: row.word_path as string | null,
    pdf_path: row.pdf_path as string | null,
    model_path: row.model_path as string | null,
    published_by: row.published_by as string | null,
    published_at: row.published_at as string | null,
    rejection_reason: row.rejection_reason as string | null,
    coverage_id: row.coverage_id as string | null,
    sector_id: row.sector_id as string | null,
    lead_analyst_email: (row.lead_analyst_email as string) ?? analystEmails[0] ?? "",
    analyst_emails: analystEmails,
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
    analysts,
  };
}

export async function listReportTypeOptions(): Promise<Result<string[]>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_type")
    .select("report_type")
    .eq("is_active", true)
    .order("sort", { ascending: true });

  if (error) {
    return err(error.message);
  }

  return ok((data ?? []).map((item) => item.report_type));
}

export async function reportTypeExists(reportType: string): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_type")
    .select("id")
    .eq("report_type", reportType)
    .eq("is_active", true)
    .limit(1);

  if (error) {
    return err(error.message);
  }

  return ok((data ?? []).length > 0);
}

export async function hasValidTemplateForReportType(
  reportType: string,
): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("report_template")
    .select("id, template_file_path")
    .eq("report_type", reportType);

  if (error) {
    return err(error.message);
  }

  const valid = (data ?? []).some(
    (row) =>
      row.template_file_path && row.template_file_path.trim().length > 0,
  );
  return ok(valid);
}

export async function regionCodeExists(regionCode: string): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("region")
    .select("code")
    .eq("code", regionCode)
    .eq("is_active", true)
    .limit(1);

  if (error) {
    return err(error.message);
  }
  return ok((data ?? []).length > 0);
}

export async function sectorExists(sectorId: string): Promise<Result<boolean>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("sector")
    .select("id")
    .eq("id", sectorId)
    .eq("is_active", true)
    .limit(1);

  if (error) {
    return err(error.message);
  }
  return ok((data ?? []).length > 0);
}

export async function findCoverageByTicker(
  ticker: string,
): Promise<Result<CoverageMatch | null>> {
  const normalizedTicker = ticker.trim().toUpperCase();
  if (!normalizedTicker) {
    return ok(null);
  }

  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("coverage")
    .select(
      `
      id,
      ticker,
      analysts:coverage_analyst (
        analyst_email
      )
    `,
    )
    .eq("is_active", true)
    .ilike("ticker", normalizedTicker)
    .limit(1)
    .maybeSingle();

  if (error) {
    return err(error.message);
  }

  if (!data) {
    return ok(null);
  }

  const analystEmails = Array.isArray(data.analysts)
    ? data.analysts
        .map((item: Record<string, string>) => item.analyst_email as string)
        .filter(Boolean)
    : [];

  return ok({
    id: data.id,
    ticker: data.ticker,
    analyst_emails: analystEmails,
  });
}

export async function listReports(
  params: ListReportsParams,
): Promise<Result<PaginatedList<ReportSummary>>> {
  const supabase = await createServerClient();

  // No FK from report.lead_analyst_email to analyst — join is done in JS below
  let queryBuilder = supabase
    .from("report")
    .select("*", { count: "exact" });

  if (params.query) {
    const term = `%${params.query}%`;
    queryBuilder = queryBuilder.ilike("title", term);
  }

  if (params.status && params.status !== "all") {
    queryBuilder = queryBuilder.eq("status", params.status);
  }

  const from = (params.page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const { data, error, count } = await queryBuilder
    .order("updated_at", { ascending: false })
    .range(from, to);

  if (error) {
    return err(error.message);
  }

  const total = count ?? 0;

  // Batch-fetch analysts by email (no FK, so JS-side join)
  const allEmails = [
    ...new Set(
      (data ?? [])
        .flatMap((item: Record<string, unknown>) => (item.analyst_emails as string[]) ?? [])
        .filter(Boolean),
    ),
  ];
  const allAnalystMap: Record<string, Record<string, unknown>> = {};
  if (allEmails.length > 0) {
    const { data: analystsData } = await supabase
      .from("analyst")
      .select("email, english_name, chinese_name")
      .in("email", allEmails);
    if (analystsData) {
      for (const a of analystsData) {
        allAnalystMap[a.email.toLowerCase()] = a;
      }
    }
  }
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  // Fetch owner names
  const ownerIds = [
    ...new Set(
      (data ?? [])
        .map((item: Record<string, unknown>) => item.owner_user_id as string)
        .filter(Boolean),
    ),
  ];
  const ownerNamesMap: Record<string, string> = {};
  for (const ownerId of ownerIds) {
    const { data: ownerName } = await supabase.rpc("get_user_full_name", {
      p_user_id: ownerId,
    });
    if (ownerName) {
      ownerNamesMap[ownerId] = ownerName;
    }
  }

  const items = (data ?? []).map((item: Record<string, unknown>) => {
    const ownerName = ownerNamesMap[(item.owner_user_id as string) ?? ""] ?? null;
    return normalizeReportSummaryRow(
      { ...item, owner_name: ownerName },
      allAnalystMap,
    );
  });

  return ok({
    items,
    total,
    page: params.page,
    totalPages,
  });
}

export async function getReportDetail(
  reportId: string,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  // No FKs from report — all relations fetched separately in JS
  const { data: reportData, error: reportError } = await supabase
    .from("report")
    .select("*")
    .eq("id", reportId)
    .single();

  if (reportError || !reportData) {
    return err(reportError?.message ?? "Report not found or no permission.");
  }

  // Fetch coverage
  let coverage: { id: string; ticker: string; english_name: string } | null = null;
  if (reportData.coverage_id) {
    const { data: covData } = await supabase
      .from("coverage")
      .select("id, ticker, english_name")
      .eq("id", reportData.coverage_id)
      .maybeSingle();
    coverage = covData ?? null;
  }

  // Fetch region
  let region: { id: string; name_en: string; name_cn: string; code: string; is_active: boolean } | null = null;
  if (reportData.region_code) {
    const { data: regData } = await supabase
      .from("region")
      .select("id, name_en, name_cn, code, is_active")
      .eq("code", reportData.region_code)
      .maybeSingle();
    region = regData ?? null;
  }

  // Fetch sector
  let sector: { id: string; name_en: string; name_cn: string | null } | null = null;
  if (reportData.sector_id) {
    const { data: secData } = await supabase
      .from("sector")
      .select("id, name_en, name_cn")
      .eq("id", reportData.sector_id)
      .maybeSingle();
    sector = secData ?? null;
  }

  // Fetch status logs
  const { data: logs, error: logError } = await supabase
    .from("report_status_log")
    .select("*")
    .eq("report_id", reportId)
    .order("action_at", { ascending: false });

  if (logError) {
    return err(logError.message);
  }

  // Fetch owner name
  let ownerName: string | null = null;
  if (reportData.owner_user_id) {
    const { data: ownerNameData } = await supabase.rpc("get_user_full_name", {
      p_user_id: reportData.owner_user_id,
    });
    ownerName = ownerNameData ?? null;
  }

  // Fetch all analysts from analyst_emails array (no FK, so JS-side join)
  const analystEmails: string[] = (reportData.analyst_emails as string[]) ?? [];
  const allAnalystMap: Record<string, Record<string, unknown>> = {};
  if (analystEmails.length > 0) {
    const { data: analystsData } = await supabase
      .from("analyst")
      .select("email, english_name, chinese_name")
      .in("email", analystEmails);
    if (analystsData) {
      for (const a of analystsData) {
        allAnalystMap[a.email.toLowerCase()] = a;
      }
    }
  }

  // Fetch unique user IDs from status_logs for name resolution
  const uniqueUserIds = [
    ...new Set(
      (logs ?? [])
        .map((l: Record<string, unknown>) => l.action_by as string)
        .filter(Boolean),
    ),
  ];
  const userNamesMap: Record<string, string> = {};
  for (const userId of uniqueUserIds) {
    const { data: userData } = await supabase.rpc("get_user_full_name", {
      p_user_id: userId,
    });
    if (userData) {
      userNamesMap[userId] = userData;
    }
  }

  const processedLogs = (logs ?? []).map((l: Record<string, unknown>) => ({
    ...l,
    action_by_name: userNamesMap[l.action_by as string] ?? null,
    metadata: (l.metadata as Record<string, unknown>) ?? {},
  })) as ReportStatusLog[];

  const summary = normalizeReportSummaryRow(
    { ...reportData, owner_name: ownerName },
    allAnalystMap,
  );

  const detail: ReportDetail = {
    ...summary,
    coverage,
    region,
    sector,
    status_logs: processedLogs,
  };

  return ok(detail);
}

/**
 * Create a new report via upsert_report RPC.
 * analyst_emails are stored directly on report.
 */
export async function createReport(
  params: CreateReportParams,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const analystEmails = params.analysts.map((a) => ({
    analyst_email: a.analyst_email.toLowerCase(),
    author_order: a.author_order,
  }));

  const { error } = await supabase.rpc("upsert_report", {
    p_draft: {
      report_id: params.report_id ?? crypto.randomUUID(),
      title: params.title,
      report_type: params.report_type,
      coverage_id: params.coverage_id ?? null,
      ticker: params.ticker ?? null,
      sector_id: params.sector_id ?? null,
      region_code: params.region_code ?? null,
      rating: params.rating ?? null,
      target_price: params.target_price ?? null,
      investment_thesis: params.investment_thesis ?? null,
      report_language: params.report_language ?? null,
      contact_person: params.contact_person ?? null,
      analysts: analystEmails,
    },
  });

  if (error) {
    return err(error.message);
  }

  return getReportDetail(params.report_id ?? "");
}

/**
 * Save report content: upsert_report + update_report_doc_paths + update_model_path.
 * No more version snapshots.
 */
export async function saveReportContent(
  params: SaveReportContentParams,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const analystEmails = params.analysts.map((a) => ({
    analyst_email: a.analyst_email.toLowerCase(),
    author_order: a.author_order,
  }));

  // Step 1: upsert report metadata
  const { error: upsertError } = await supabase.rpc("upsert_report", {
    p_draft: {
      report_id: params.report_id,
      title: params.title,
      report_type: params.report_type,
      coverage_id: params.coverage_id ?? null,
      ticker: params.ticker ?? null,
      sector_id: params.sector_id ?? null,
      region_code: params.region_code ?? null,
      rating: params.rating ?? null,
      target_price: params.target_price ?? null,
      investment_thesis: params.investment_thesis ?? null,
      report_language: params.report_language ?? null,
      contact_person: params.contact_person ?? null,
      analysts: analystEmails,
    },
  });

  if (upsertError) {
    return err(upsertError.message);
  }

  // Step 2: update doc paths (word + pdf)
  if (params.word_path || params.pdf_path) {
    const { error: docError } = await supabase.rpc("update_report_doc_paths", {
      p_report_id: params.report_id,
      p_word_path: params.word_path ?? "",
      p_pdf_path: params.pdf_path ?? "",
    });
    if (docError) {
      return err(docError.message);
    }
  }

  // Step 3: update model path
  if (params.model_path) {
    const { error: modelError } = await supabase.rpc("update_model_path", {
      p_report_id: params.report_id,
      p_model_path: params.model_path,
    });
    if (modelError) {
      return err(modelError.message);
    }
  }

  return getReportDetail(params.report_id);
}

/**
 * Submit a report: calls submit_report RPC
 */
export async function submitReport(
  reportId: string,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const { error } = await supabase.rpc("submit_report", {
    p_report_id: reportId,
  });

  if (error) {
    return err(error.message);
  }

  return getReportDetail(reportId);
}

/**
 * Retract a report: calls retract_report RPC
 */
export async function retractReport(
  reportId: string,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const { error } = await supabase.rpc("retract_report", {
    p_report_id: reportId,
  });

  if (error) {
    return err(error.message);
  }

  return getReportDetail(reportId);
}

/**
 * Publish a report: calls publish_report RPC
 */
export async function publishReport(
  reportId: string,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const { error } = await supabase.rpc("publish_report", {
    p_report_id: reportId,
  });

  if (error) {
    return err(error.message);
  }

  return getReportDetail(reportId);
}

/**
 * Reject a report: calls reject_report RPC
 */
export async function rejectReport(
  reportId: string,
  reason: string,
): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const { error } = await supabase.rpc("reject_report", {
    p_report_id: reportId,
    p_rejection_reason: reason,
  });

  if (error) {
    return err(error.message);
  }

  return getReportDetail(reportId);
}

export async function getReportDownloadUrl(params: {
  report_id: string;
  file_path: string;
}): Promise<Result<string>> {
  const supabase = await createServerClient();

  // Normalize path: strip leading 'reports/' since from('reports') already includes the bucket
  const normalizedPath = params.file_path.replace(/^reports\//, "");

  const { data, error } = await supabase.storage
    .from("reports")
    .createSignedUrl(normalizedPath, 60 * 5);

  if (error || !data?.signedUrl) {
    return err(error?.message ?? "Failed to create download URL.");
  }

  return ok(data.signedUrl);
}
