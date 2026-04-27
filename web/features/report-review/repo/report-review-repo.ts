import "server-only";

import type { Result } from "@/lib/result";

import {
  getReportDetail,
  listReports,
  publishReport,
  rejectReport,
  retractReport,
  saveReportContent,
  type ReportDetail,
  type ReportSummary,
} from "@/features/reports/repo/reports-repo";
import type { ReportAnalystInput } from "@/domain/schemas/report";

export async function listReviewReports(params: {
  page: number;
  query: string | null;
  status: "all" | "submitted" | "published" | "rejected";
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
}): Promise<Result<ReportDetail>> {
  return saveReportContent({
    report_id: params.report_id,
    title: params.title,
    report_type: params.report_type,
    ticker: params.ticker,
    rating: params.rating,
    target_price: params.target_price,
    region_code: params.region_code,
    sector_id: params.sector_id,
    report_language: params.report_language,
    contact_person: params.contact_person,
    investment_thesis: params.investment_thesis,
    coverage_id: params.coverage_id,
    analysts: params.analysts,
    changed_by: params.changed_by,
    word_path: params.word_path,
    pdf_path: params.pdf_path,
    model_path: params.model_path,
  });
}
