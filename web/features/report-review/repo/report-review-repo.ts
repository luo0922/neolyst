import "server-only";

import type { Result } from "@/lib/result";
import { createServerClient } from "@/lib/supabase/server";

import {
  getReportDetail,
  listReports,
  publishReport,
  rejectReport,
  retractReport,
  type ReportDetail,
  type ReportSummary,
} from "@/features/reports/repo/reports-repo";
import type { ReportAnalystInput } from "@/domain/schemas/report";

export async function listReviewReports(params: {
  page: number;
  query: string | null;
  status: "all" | "submitted" | "published" | "rejected" | "terminated";
  report_type?: string | null;
  contact_person?: string | null;
  analyst?: string | null;
}): Promise<
  Result<{
    items: ReportSummary[];
    total: number;
    page: number;
    totalPages: number;
  }>
> {
  return listReports({
    page: params.page,
    query: params.query,
    status: params.status,
    report_type: params.report_type,
    contact_person: params.contact_person,
    analyst: params.analyst,
  });
}

export async function getReviewReportDetail(
  reportId: string,
): Promise<Result<ReportDetail>> {
  return getReportDetail(reportId);
}

export async function approveReport(params: {
  report_id: string;
  action_by: string;
}): Promise<Result<ReportDetail>> {
  // New schema: calls publish_report RPC directly
  const statusResult = await publishReport(params.report_id);

  if (!statusResult.ok) {
    return statusResult;
  }

  return statusResult;
}

export async function rejectReportAction(params: {
  report_id: string;
  action_by: string;
  reason: string;
}): Promise<Result<ReportDetail>> {
  // New schema: calls reject_report RPC with reason
  return rejectReport(params.report_id, params.reason);
}

export async function reopenReportAction(params: {
  report_id: string;
  action_by: string;
}): Promise<Result<ReportDetail>> {
  // New schema: calls retract_report RPC
  return retractReport(params.report_id);
}

export async function saveReviewReportContent(params: {
  report_id: string;
  title: string;
  report_type: string;
  ticker?: string | null;
  rating?: string | null;
  target_price?: string | null;
  region_code?: string | null;
  sector_id?: string | null;
  report_language?: "en" | "zh" | null;
  contact_person?: string | null;
  investment_thesis?: string | null;
  coverage_id?: string | null;
  analysts: ReportAnalystInput[];
  changed_by: string;
  word_path?: string | null;
  pdf_path?: string | null;
  model_path?: string | null;
  chief_approval_path?: string | null;
  source_path?: string | null;
  source_filename?: string | null;
}): Promise<Result<ReportDetail>> {
  const supabase = await createServerClient();

  const analystEmails = params.analysts.map((a) =>
    a.analyst_email.toLowerCase(),
  );
  const leadAnalyst = analystEmails[0] ?? null;

  const updateData: Record<string, unknown> = {
    title: params.title,
    investment_thesis: params.investment_thesis ?? null,
    lead_analyst_email: leadAnalyst,
    analyst_emails: analystEmails,
    contact_person: params.contact_person ?? null,
  };
  if (params.word_path) {
    updateData.word_path = params.word_path;
  }
  if (params.pdf_path) {
    updateData.pdf_path = params.pdf_path;
  }
  if (params.model_path) {
    updateData.model_path = params.model_path;
  }
  if (params.chief_approval_path) {
    updateData.chief_approval_path = params.chief_approval_path;
  }
  if (params.source_path !== undefined) {
    updateData.source_path = params.source_path;
  }
  if (params.source_filename !== undefined) {
    updateData.source_filename = params.source_filename;
  }

  const { error } = await supabase
    .from("report")
    .update(updateData)
    .eq("id", params.report_id)
    .eq("status", "submitted");

  if (error) {
    return { ok: false, error: error.message };
  }

  return getReportDetail(params.report_id);
}
