"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { FileDropzone } from "@/components/ui/file-dropzone";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { RichTextEditor } from "@/components/ui/rich-text-editor";
import { useToast } from "@/components/ui/toast";
import type { ReportAnalystInput } from "@/domain/schemas/report";
import type { ReportDetail } from "@/features/reports/repo/reports-repo";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";
import {
  getReportDownloadUrlAction,
  uploadReportFileAction,
} from "@/features/reports/actions";
import { validatePdfExtension, validateWordPptExtension } from "@/features/reports/file-utils";

import {
  executeReviewAction,
  getReviewReportDetailAction,
  saveReviewReportAction,
} from "../actions";

function formatDateTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) {
    return iso;
  }
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(d);
}

export interface ReviewReportPageProps {
  reportId: string;
  userRole: "admin" | "sa";
  analysts: Analyst[];
}

export function ReviewReportPage({
  reportId,
  userRole: _userRole,
  analysts: analystsProp,
}: ReviewReportPageProps) {
  const router = useRouter();
  const toast = useToast();

  const [loading, setLoading] = React.useState(true);
  const [detail, setDetail] = React.useState<ReportDetail | null>(null);
  const [reportFile, setReportFile] = React.useState<File | null>(null);
  const [pdfFile, setPdfFile] = React.useState<File | null>(null);
  const [modelFile, setModelFile] = React.useState<File | null>(null);
  const [rejectReason, setRejectReason] = React.useState("");
  const [actionLoading, setActionLoading] = React.useState(false);

  // Form state
  const [formTitle, setFormTitle] = React.useState("");
  const [formInvestmentThesis, setFormInvestmentThesis] = React.useState("");
  const [formAnalysts, setFormAnalysts] = React.useState<ReportAnalystInput[]>([]);

  React.useEffect(() => {
    async function loadData() {
      const detailResult = await getReviewReportDetailAction(reportId);
      setLoading(false);

      if (!detailResult.ok) {
        toast.error(detailResult.error, { title: "Error" });
        return;
      }

      setDetail(detailResult.data);
      setFormTitle(detailResult.data.title);
      setFormInvestmentThesis(detailResult.data.investment_thesis ?? "");
      setFormAnalysts(
        detailResult.data.analysts
          .sort((a, b) => a.author_order - b.author_order)
          .map((item) => ({
            analyst_email: item.analyst_email,
            author_order: item.author_order,
          }))
      );
    }

    loadData();
  }, [reportId, toast]);

  function getAnalystOptions(index: number): { value: string; label: string }[] {
    const selectedOthers = new Set(
      formAnalysts
        .filter((_, idx) => idx !== index)
        .map((item) => item.analyst_email)
        .filter(Boolean)
    );
    const current = formAnalysts[index]?.analyst_email;

    return [
      { value: "", label: "Select analyst..." },
      ...analystsProp
        .filter((item) => item.email === current || !selectedOthers.has(item.email))
        .map((item) => ({
          value: item.email,
          label: `${item.english_name ?? item.email} (${item.email})`,
        })),
    ];
  }

  function addAnalyst() {
    if (formAnalysts.length >= 4) return;
    setFormAnalysts((prev) => [
      ...prev,
      { analyst_email: "", author_order: prev.length + 1 },
    ]);
  }

  function removeAnalyst(index: number) {
    setFormAnalysts((prev) =>
      prev
        .filter((_, idx) => idx !== index)
        .map((item, idx) => ({ ...item, author_order: idx + 1 }))
    );
  }

  function updateAnalyst(index: number, analystEmail: string) {
    setFormAnalysts((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], analyst_email: analystEmail };
      return next;
    });
  }

  async function handleDownload(filePath: string, _fileName?: string) {
    if (!detail) {
      return;
    }

    const result = await getReportDownloadUrlAction({
      report_id: detail.id,
      file_path: filePath,
    });

    if (!result.ok) {
      toast.error(result.error, { title: "Error" });
      return;
    }

    window.open(result.data, "_blank", "noopener,noreferrer");
  }

  async function uploadReportFiles(): Promise<{
    word_path: string | null;
    pdf_path: string | null;
    model_path: string | null;
  }> {
    let wordPath: string | null = detail?.word_path ?? null;
    let pdfPath: string | null = detail?.pdf_path ?? null;
    const modelPath: string | null = detail?.model_path ?? null;

    // Upload Word/PPT file
    if (reportFile) {
      const check = validateWordPptExtension(reportFile.name);
      if (!check.ok) {
        toast.error(check.error, { title: "Validation Error" });
        return { word_path: null, pdf_path: null, model_path: null };
      }

      const fd = new FormData();
      fd.append("file", reportFile);
      fd.append("reportId", detail!.id);
      fd.append("label", "report");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        toast.error(result.error, { title: "Upload Error" });
        return { word_path: null, pdf_path: null, model_path: null };
      }
      wordPath = result.file_path;
    }

    // Upload PDF file
    if (pdfFile) {
      const check = validatePdfExtension(pdfFile.name);
      if (!check.ok) {
        toast.error(check.error, { title: "Validation Error" });
        return { word_path: null, pdf_path: null, model_path: null };
      }

      const fd = new FormData();
      fd.append("file", pdfFile);
      fd.append("reportId", detail!.id);
      fd.append("label", "report-pdf");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        toast.error(result.error, { title: "Upload Error" });
        return { word_path: null, pdf_path: null, model_path: null };
      }
      pdfPath = result.file_path;
    }

    return {
      word_path: wordPath,
      pdf_path: pdfPath,
      model_path: modelPath,
    };
  }

  async function runAction(action: "approve" | "reject" | "reopen") {
    if (!detail) {
      return;
    }

    // Approve requires PDF
    if (action === "approve") {
      const hasNewPdfFile = pdfFile !== null;
      const hasExistingPdfFile = !!detail.pdf_path;

      if (!hasNewPdfFile && !hasExistingPdfFile) {
        toast.error("Approve requires a PDF report file to be uploaded.", {
          title: "Validation Error",
        });
        return;
      }
    }

    setActionLoading(true);

    // Save changes if any
    const hasChanges =
      reportFile ||
      pdfFile ||
      formTitle !== detail.title ||
      formInvestmentThesis !== (detail.investment_thesis ?? "");

    if (hasChanges) {
      const uploadResult = await uploadReportFiles();
      if (
        uploadResult.word_path === null &&
        uploadResult.pdf_path === null &&
        (reportFile || pdfFile)
      ) {
        setActionLoading(false);
        return;
      }

      const saveResult = await saveReviewReportAction({
        report_id: detail.id,
        title: formTitle.trim(),
        report_type: detail.report_type,
        ticker: detail.ticker,
        rating: detail.rating,
        target_price: detail.target_price,
        region_code: detail.region_code,
        sector_id: detail.sector_id,
        report_language: detail.report_language,
        contact_person: detail.contact_person,
        investment_thesis: formInvestmentThesis || null,
        coverage_id: detail.coverage_id,
        analysts: formAnalysts,
        word_path: uploadResult.word_path,
        pdf_path: uploadResult.pdf_path,
        model_path: uploadResult.model_path,
      });

      if (!saveResult.ok) {
        setActionLoading(false);
        toast.error(saveResult.error, { title: "Error saving changes" });
        return;
      }

      setDetail(saveResult.data);
      setReportFile(null);
      setPdfFile(null);
    }

    const payload =
      action === "reject"
        ? { action, report_id: detail.id, reason: rejectReason }
        : { action, report_id: detail.id };

    const result = await executeReviewAction(payload);
    setActionLoading(false);

    if (!result.ok) {
      toast.error(result.error, { title: "Error" });
      return;
    }

    setDetail(result.data);
    if (action === "reject") {
      setRejectReason("");
    }
    router.push("/report-review");
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-[var(--bg-app)]">
        <div className="mx-auto max-w-5xl px-6 py-8">
          <div className="py-10 text-center text-[var(--fg-secondary)]">
            Loading...
          </div>
        </div>
      </div>
    );
  }

  if (!detail) {
    return (
      <div className="min-h-screen bg-[var(--bg-app)]">
        <div className="mx-auto max-w-5xl px-6 py-8">
          <div className="py-10 text-center text-[var(--fg-secondary)]">
            Report not found.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[var(--bg-app)]">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <div className="flex items-center gap-4">
            <Link href="/report-review">
              <Button type="button" variant="ghost">
                <svg
                  className="mr-2 h-4 w-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 19l-7-7 7-7"
                  />
                </svg>
                Back
              </Button>
            </Link>
            <div>
              <div className="text-xl font-semibold text-[var(--fg-primary)]">
                Quality Review
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-5xl space-y-6 px-6 py-8">
        {/* Basic Info Section */}
        <section className="rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Information
          </h2>
          <div className="space-y-4">
            <Input
              label="Title"
              value={formTitle}
              onChange={(e) => setFormTitle(e.target.value)}
            />
          </div>
          <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <span className="text-sm text-[var(--fg-tertiary)]">Type:</span>
              <span className="ml-2 text-sm text-[var(--fg-primary)]">
                {detail?.report_type}
              </span>
            </div>
            {detail?.ticker && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Ticker:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.ticker}
                </span>
              </div>
            )}
            {detail?.rating && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Rating:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.rating}
                </span>
              </div>
            )}
            {detail?.target_price && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Target Price:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.target_price}
                </span>
              </div>
            )}
            {detail.region && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Region:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.region.name_en}
                </span>
              </div>
            )}
            {detail.sector && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Sector:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.sector.name_en}
                </span>
              </div>
            )}
            {detail.report_language && (
              <div>
                <span className="text-sm text-[var(--fg-tertiary)]">
                  Language:
                </span>
                <span className="ml-2 text-sm text-[var(--fg-primary)]">
                  {detail.report_language === "en"
                    ? "English"
                    : detail.report_language === "zh"
                      ? "Chinese"
                      : detail.report_language}
                </span>
              </div>
            )}
          </div>

          {detail.coverage && (
            <div className="mt-4">
              <span className="text-sm text-[var(--fg-tertiary)]">
                Coverage:
              </span>
              <span className="ml-2 text-sm text-[var(--fg-primary)]">
                {detail.coverage.english_name}
              </span>
            </div>
          )}

          <div className="mt-4">
            <RichTextEditor
              label="Investment Thesis"
              value={formInvestmentThesis}
              onChange={setFormInvestmentThesis}
              minHeight="150px"
            />
          </div>

          {/* Analysts Section */}
          <div className="mt-4">
            <div className="mb-2 text-sm font-medium text-[var(--fg-primary)]">
              Analysts
            </div>
            {formAnalysts.length === 0 ? (
              <p className="text-sm text-[var(--fg-tertiary)]">
                No analyst assigned.
              </p>
            ) : (
              formAnalysts.map((item, index) => (
                <div
                  key={`${item.analyst_email}-${index}`}
                  className="mb-2 grid grid-cols-12 gap-2"
                >
                  <div className="col-span-9">
                    <Select
                      value={item.analyst_email}
                      onChange={(e) =>
                        updateAnalyst(index, e.target.value)
                      }
                      options={getAnalystOptions(index)}
                    />
                  </div>
                  <div className="col-span-1 flex items-center text-xs text-[var(--fg-secondary)]">
                    #{index + 1}
                  </div>
                  <div className="col-span-2">
                    <Button
                      type="button"
                      variant="ghost"
                      className="w-full"
                      onClick={() => removeAnalyst(index)}
                    >
                      Remove
                    </Button>
                  </div>
                </div>
              ))
            )}
            {formAnalysts.length < 4 && (
              <Button
                type="button"
                variant="secondary"
                onClick={addAnalyst}
                className="mt-2"
              >
                Add Analyst
              </Button>
            )}
          </div>
        </section>

        {/* Files Section */}
        <section className="rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Files
          </h2>
          <div className="space-y-4">
            {/* Report File - show saved or newly selected */}
            {(detail.word_path || reportFile) ? (
              <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                {reportFile ? (
                  <div className="flex items-center gap-2 text-sm text-green-600">
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    Selected: {reportFile.name}
                  </div>
                ) : detail.word_path ? (
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        detail.word_path!,
                        detail.word_path!.split("/").pop() ?? "report",
                      )
                    }
                  >
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                    Report File
                  </button>
                ) : null}
              </div>
            ) : null}

            {/* PDF File - show saved or newly selected */}
            {(detail.pdf_path || pdfFile) ? (
              <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                {pdfFile ? (
                  <div className="flex items-center gap-2 text-sm text-green-600">
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    Selected: {pdfFile.name}
                  </div>
                ) : detail.pdf_path ? (
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        detail.pdf_path!,
                        detail.pdf_path!.split("/").pop() ?? "report.pdf",
                      )
                    }
                  >
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                    PDF File
                  </button>
                ) : null}
              </div>
            ) : null}

            {/* Existing Model File */}
            {detail.model_path ? (
              <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                <button
                  type="button"
                  className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                  onClick={() =>
                    handleDownload(
                      detail.model_path!,
                      detail.model_path!.split("/").pop() ?? "model",
                    )
                  }
                >
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Model File
                </button>
              </div>
            ) : null}

            <FileDropzone
              label="Report File (Word/PPT)"
              accept=".doc,.docx,.ppt,.pptx"
              file={reportFile}
              onFileChange={setReportFile}
              hint="Supports .doc/.docx/.ppt/.pptx"
            />

            <FileDropzone
              label="Report Pdf (PDF)"
              accept=".pdf"
              file={pdfFile}
              onFileChange={setPdfFile}
              hint="Supports .pdf"
            />

            <FileDropzone
              label="Model File"
              accept=".xls,.xlsx,.csv"
              file={modelFile}
              onFileChange={setModelFile}
              hint="Supports .xls/.xlsx/.csv"
            />
          </div>
        </section>

        {/* Status History Section (no version history) */}
        <section className="rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Status History
          </h2>
          {detail.status_logs.length === 0 ? (
            <p className="text-sm text-[var(--fg-tertiary)]">No history yet.</p>
          ) : (
            <div className="space-y-2">
              {detail.status_logs.map((item) => (
                <div
                  key={item.id}
                  className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3 text-sm"
                >
                  <div className="flex items-center gap-2 text-[var(--fg-primary)]">
                    <span>{item.from_status}</span>
                    <span className="text-[var(--fg-tertiary)]">-&gt;</span>
                    <span>{item.to_status}</span>
                  </div>
                  <div className="mt-1 text-xs text-[var(--fg-tertiary)]">
                    {formatDateTime(item.action_at)} by{" "}
                    {item.action_by_name ??
                      `${item.action_by.slice(0, 8)}...`}
                  </div>
                  {item.reason ? (
                    <div className="mt-1 text-xs text-amber-300">
                      Note: {item.reason}
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Action Buttons */}
        <div className="flex justify-between">
          <div className="flex gap-3">
            <Link href="/report-review">
              <Button type="button" variant="secondary">
                Back to Review List
              </Button>
            </Link>
          </div>
          <div className="flex gap-3">
            {detail.status === "submitted" && (
              <>
                <Input
                  label="Reject Note"
                  placeholder="Note is required when rejecting"
                  value={rejectReason}
                  onChange={(event) => setRejectReason(event.target.value)}
                  className="w-64"
                />
                <Button
                  type="button"
                  variant="danger"
                  onClick={() => runAction("reject")}
                  isLoading={actionLoading}
                  disabled={!rejectReason.trim()}
                >
                  Reject
                </Button>
                <Button
                  type="button"
                  onClick={() => runAction("approve")}
                  isLoading={actionLoading}
                >
                  Approve
                </Button>
              </>
            )}
            {detail.status === "rejected" && (
              <Button
                type="button"
                onClick={() => runAction("reopen")}
                isLoading={actionLoading}
              >
                Reopen to Draft
              </Button>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
