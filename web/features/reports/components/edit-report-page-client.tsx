"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { FileDropzone } from "@/components/ui/file-dropzone";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { RichTextEditor } from "@/components/ui/rich-text-editor";
import { Select } from "@/components/ui/select";
import { SearchableSelect } from "@/components/ui/searchable-select";
import { useToast } from "@/components/ui/toast";
import type {
  ReportAnalystInput,
  ReportLanguage,
  ReportType,
} from "@/domain/schemas/report";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";
import type { CoverageWithDetails } from "@/features/coverage/repo/coverage-repo";
import type { Region } from "@/features/regions/repo/regions-repo";
import type { Rating } from "@/features/ratings/repo/ratings-repo";
import type { SectorWithChildren } from "@/features/sectors/repo/sectors-repo";
import {
  type ReportDetail,
} from "@/features/reports/repo/reports-repo";
import {
  directSubmitReportAction,
  getReportDownloadUrlAction,
  retractReportAction,
  saveReportContentAction,
  uploadReportFileAction,
} from "@/features/reports/actions";
import {
  validateUploadExtension,
  validateWordPptExtension,
  validatePdfExtension,
  validateImageExtension,
} from "@/features/reports/file-utils";

const LANGUAGE_OPTIONS: { value: ReportLanguage; label: string }[] = [
  { value: "en", label: "English" },
  { value: "zh", label: "Chinese" },
];

function formatReportTypeLabel(value: string): string {
  return value
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

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

export interface EditReportPageClientProps {
  report: ReportDetail;
  userRole: "admin" | "analyst";
  currentUserId: string;
  reportTypes: string[];
  analysts: Analyst[];
  regions: Region[];
  sectors: SectorWithChildren[];
  coverages: CoverageWithDetails[];
  ratings: Rating[];
}

export function EditReportPageClient({
  report: initialReport,
  userRole,
  currentUserId,
  reportTypes,
  analysts,
  regions,
  sectors,
  coverages,
  ratings,
}: EditReportPageClientProps) {
  const router = useRouter();
  const toast = useToast();

  const [activeReport, setActiveReport] = React.useState<ReportDetail>(initialReport);
  const [saving, setSaving] = React.useState(false);

  const reportTypeOptions = React.useMemo(
    () =>
      reportTypes.map((value) => ({
        value,
        label: formatReportTypeLabel(value),
      })),
    [reportTypes],
  );

  const ratingOptions = React.useMemo(
    () =>
      ratings.map((rating) => ({
        value: rating.code,
        label: `${rating.name} (${rating.code})`,
      })),
    [ratings],
  );

  const canEdit =
    userRole === "admin" ||
    (userRole === "analyst" &&
      activeReport.owner_user_id === currentUserId &&
      (activeReport.status === "draft" ||
        activeReport.status === "rejected" ||
        activeReport.status === "submitted"));

  const canSubmit =
    activeReport.status === "draft" &&
    (userRole === "admin" ||
      (userRole === "analyst" && activeReport.owner_user_id === currentUserId));

  const [formTitle, setFormTitle] = React.useState(initialReport.title);
  const [formReportType, setFormReportType] = React.useState<ReportType>(
    initialReport.report_type,
  );
  const [formTicker, setFormTicker] = React.useState(
    initialReport.ticker ?? "",
  );
  const [formRating, setFormRating] = React.useState(
    initialReport.rating ?? "",
  );
  const [formTargetPrice, setFormTargetPrice] = React.useState(
    initialReport.target_price ?? "",
  );
  const [formRegionCode, setFormRegionId] = React.useState(
    initialReport.region_code ?? "",
  );
  const [formSectorId, setFormSectorId] = React.useState(
    initialReport.sector_id ?? "",
  );
  const [formLanguage, setFormLanguage] = React.useState<ReportLanguage>(
    initialReport.report_language ?? "en",
  );
  const [formContactPerson, setFormContactPerson] = React.useState(
    initialReport.contact_person ?? "",
  );
  const [formInvestmentThesis, setFormInvestmentThesis] = React.useState(
    initialReport.investment_thesis ?? "",
  );
  const [formAnalysts, setFormAnalysts] = React.useState<ReportAnalystInput[]>(
    initialReport.analysts
      .sort((a, b) => a.author_order - b.author_order)
      .map((item) => ({
        analyst_email: item.analyst_email,
        author_order: item.author_order,
      })),
  );
  const [formErrors, setFormErrors] = React.useState<Record<string, string>>(
    {},
  );

  const [reportFile, setReportFile] = React.useState<File | null>(null);
  const [pdfFile, setPdfFile] = React.useState<File | null>(null);
  const [modelFile, setModelFile] = React.useState<File | null>(null);
  const [chiefApprovalFile, setChiefApprovalFile] = React.useState<File | null>(null);
  const [sourceFile, setSourceFile] = React.useState<File | null>(null);

  React.useEffect(() => {
    if (!reportTypes.includes(formReportType) && reportTypes.length > 0) {
      setFormReportType(reportTypes[0]);
    }
  }, [formReportType, reportTypes]);

  function getAnalystOptions(
    index: number,
  ): { value: string; label: string }[] {
    const selectedOthers = new Set(
      formAnalysts
        .filter((_, idx) => idx !== index)
        .map((item) => item.analyst_email)
        .filter(Boolean),
    );
    const current = formAnalysts[index]?.analyst_email;

    return [
      { value: "", label: "Select analyst..." },
      ...analysts
        .filter(
          (item) => item.email === current || !selectedOthers.has(item.email),
        )
        .map((item) => ({
          value: item.email,
          label: `${item.english_name ?? item.email} (${item.email})`,
        })),
    ];
  }

  function addAnalyst() {
    if (formAnalysts.length >= 4) {
      return;
    }
    setFormAnalysts((prev) => [
      ...prev,
      { analyst_email: "", author_order: prev.length + 1 },
    ]);
  }

  function removeAnalyst(index: number) {
    setFormAnalysts((prev) =>
      prev
        .filter((_, idx) => idx !== index)
        .map((item, idx) => ({ ...item, author_order: idx + 1 })),
    );
  }

  function updateAnalyst(index: number, analystEmail: string) {
    setFormAnalysts((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], analyst_email: analystEmail };
      return next;
    });
  }

  function buildValidatedAnalysts(): ReportAnalystInput[] {
    return formAnalysts
      .filter((item) => item.analyst_email)
      .map((item, index) => ({
        analyst_email: item.analyst_email,
        author_order: index + 1,
      }));
  }

  function validateForm(): ReportAnalystInput[] | null {
    const errors: Record<string, string> = {};

    if (!formTitle.trim()) {
      errors.title = "Title is required";
    }

    if (!formReportType.trim()) {
      errors.report_type = "Report Type is required";
    }

    const validatedAnalysts = buildValidatedAnalysts();
    const unique = new Set(
      validatedAnalysts.map((item) => item.analyst_email.toLowerCase()),
    );
    if (unique.size !== validatedAnalysts.length) {
      errors.analysts = "Analysts must be unique";
    }

    setFormErrors(errors);
    if (Object.keys(errors).length > 0) {
      return null;
    }
    return validatedAnalysts;
  }

  async function uploadReportFiles(): Promise<
    | {
        ok: true;
        data: {
          word_path: string | null;
          pdf_path: string | null;
          model_path: string | null;
          model_filename: string | null;
          chief_approval_path: string | null;
          source_path: string | null;
          source_filename: string | null;
        };
      }
    | { ok: false; error: string }
  > {
    const reportId = activeReport.id;

    let wordPath: string | null = activeReport?.word_path ?? null;
    let pdfPath: string | null = activeReport?.pdf_path ?? null;
    let modelPath: string | null = activeReport?.model_path ?? null;
    // model_filename: 原始文件名（含中文等），用于显示；保留 report 中已有的值，
    // 仅当用户重新上传时更新。
    let modelFilename: string | null = activeReport?.model_filename ?? null;
    let chiefApprovalPath: string | null = activeReport?.chief_approval_path ?? null;
    let sourcePath: string | null = activeReport?.source_path ?? null;
    let sourceFilename: string | null = activeReport?.source_filename ?? null;

    // Upload Word/PPT file
    if (reportFile) {
      const check = validateWordPptExtension(reportFile.name);
      if (!check.ok) {
        return { ok: false, error: check.error };
      }

      const fd = new FormData();
      fd.append("file", reportFile);
      fd.append("reportId", reportId);
      fd.append("label", "report");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        return { ok: false, error: result.error };
      }
      wordPath = result.file_path;
    }

    // Upload PDF file
    if (pdfFile) {
      const check = validatePdfExtension(pdfFile.name);
      if (!check.ok) {
        return { ok: false, error: check.error };
      }

      const fd = new FormData();
      fd.append("file", pdfFile);
      fd.append("reportId", reportId);
      fd.append("label", "report-pdf");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        return { ok: false, error: result.error };
      }
      pdfPath = result.file_path;
    }

    // Upload Model file
    if (modelFile) {
      const check = validateUploadExtension("model", modelFile.name);
      if (!check.ok) {
        return { ok: false, error: check.error };
      }

      const fd = new FormData();
      fd.append("file", modelFile);
      fd.append("reportId", reportId);
      fd.append("label", "model");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        return { ok: false, error: result.error };
      }
      modelPath = result.file_path;
      // 保留原始文件名（含中文等），用于在 UI 上展示。Storage 中存的是 ASCII-safe 名称。
      modelFilename = result.file_name;
    }

    // Upload Chief Approval file
    if (chiefApprovalFile) {
      const check = validateImageExtension(chiefApprovalFile.name);
      if (!check.ok) {
        return { ok: false, error: check.error };
      }

      const fd = new FormData();
      fd.append("file", chiefApprovalFile);
      fd.append("reportId", reportId);
      fd.append("label", "chief-approval");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        return { ok: false, error: result.error };
      }
      chiefApprovalPath = result.file_path;
    }

    // Upload Source file (original report)
    if (sourceFile) {
      const check = validateWordPptExtension(sourceFile.name);
      if (!check.ok) {
        return { ok: false, error: check.error };
      }

      const fd = new FormData();
      fd.append("file", sourceFile);
      fd.append("reportId", reportId);
      fd.append("label", "source");

      const result = await uploadReportFileAction(fd);
      if (!result.ok) {
        return { ok: false, error: result.error };
      }
      sourcePath = result.file_path;
      sourceFilename = sourceFile.name; // 保留原始文件名（含中文）
    }

    return {
      ok: true,
      data: {
        word_path: wordPath,
        pdf_path: pdfPath,
        model_path: modelPath,
        model_filename: modelFilename,
        chief_approval_path: chiefApprovalPath,
        source_path: sourcePath,
        source_filename: sourceFilename,
      },
    };
  }

  async function handleSaveDraft() {
    if (!canEdit) {
      toast.error("No permission", { title: "Error" });
      return;
    }

    const analystsValue = validateForm();
    if (!analystsValue) {
      return;
    }

    setSaving(true);
    try {
      const uploadResult = await uploadReportFiles();
      if (!uploadResult.ok) {
        toast.error(uploadResult.error, { title: "Error" });
        return;
      }

      const saveResult = await saveReportContentAction({
        report_id: activeReport.id,
        title: formTitle.trim(),
        report_type: formReportType,
        ticker: formTicker || null,
        rating: formRating || null,
        target_price: formTargetPrice || null,
        region_code: formRegionCode || null,
        sector_id: formSectorId || null,
        report_language: formLanguage,
        contact_person: formContactPerson || null,
        investment_thesis: formInvestmentThesis || null,
        analysts: analystsValue,
        word_path: uploadResult.data.word_path,
        pdf_path: uploadResult.data.pdf_path,
        model_path: uploadResult.data.model_path,
        model_filename: uploadResult.data.model_filename,
        chief_approval_path: uploadResult.data.chief_approval_path,
        source_path: uploadResult.data.source_path,
        source_filename: uploadResult.data.source_filename,
      });

      if (!saveResult.ok) {
        toast.error(saveResult.error, { title: "Error" });
        return;
      }

      // Auto-retract if report is submitted or rejected
      if (
        activeReport.status === "submitted" ||
        activeReport.status === "rejected"
      ) {
        const retractResult = await retractReportAction(activeReport.id);
        if (!retractResult.ok) {
          toast.error(retractResult.error, { title: "Error" });
          return;
        }
        setActiveReport(retractResult.data);
      } else {
        setActiveReport(saveResult.data);
      }

      setReportFile(null);
      setPdfFile(null);
      setModelFile(null);
      setChiefApprovalFile(null);
      setSourceFile(null);
      toast.success("Draft saved.", { title: "Success" });
      router.refresh();
    } finally {
      setSaving(false);
    }
  }

  async function handleSubmit() {
    if (!canEdit) {
      toast.error("No permission", { title: "Error" });
      return;
    }

    const analystsValue = validateForm();
    if (!analystsValue) {
      return;
    }

    setSaving(true);
    try {
      const uploadResult = await uploadReportFiles();
      if (!uploadResult.ok) {
        toast.error(uploadResult.error, { title: "Error" });
        return;
      }

      const directResult = await directSubmitReportAction({
        report_id: activeReport.id,
        title: formTitle.trim(),
        report_type: formReportType,
        ticker: formTicker || null,
        rating: formRating || null,
        target_price: formTargetPrice || null,
        region_code: formRegionCode || null,
        sector_id: formSectorId || null,
        report_language: formLanguage,
        contact_person: formContactPerson || null,
        investment_thesis: formInvestmentThesis || null,
        analysts: analystsValue,
        word_path: uploadResult.data.word_path,
        pdf_path: uploadResult.data.pdf_path,
        model_path: uploadResult.data.model_path,
        model_filename: uploadResult.data.model_filename,
        chief_approval_path: uploadResult.data.chief_approval_path,
        source_path: uploadResult.data.source_path,
        source_filename: uploadResult.data.source_filename,
      });

      if (!directResult.ok) {
        toast.error(directResult.error, { title: "Error" });
        return;
      }

      setActiveReport(directResult.data);
      setReportFile(null);
      setPdfFile(null);
      setModelFile(null);
      setChiefApprovalFile(null);
      setSourceFile(null);
      toast.success("Report submitted.", { title: "Success" });
      router.push("/reports");
      router.refresh();
    } finally {
      setSaving(false);
    }
  }

  async function handleDownload(filePath: string, fileName: string) {
    const result = await getReportDownloadUrlAction({
      report_id: activeReport.id,
      file_path: filePath,
    });

    if (!result.ok) {
      toast.error(result.error, { title: "Error" });
      return;
    }

    try {
      const response = await fetch(result.data);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch {
      window.open(result.data, "_blank", "noopener,noreferrer");
    }
  }

  // Helper to get chief_approval_path with fallback to current report
  function getChiefApprovalPath(item: ReportDetail["status_logs"][number]): string | null {
    return item.metadata.chief_approval_path ?? activeReport.chief_approval_path ?? null;
  }

  // Helper to get source info with fallback to current report
  function getSourcePath(item: ReportDetail["status_logs"][number]): string | null {
    return item.metadata.source_path ?? activeReport.source_path ?? null;
  }

  function getSourceFilename(item: ReportDetail["status_logs"][number]): string | null {
    return item.metadata.source_filename ?? activeReport.source_filename ?? null;
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <div>
            <div className="text-xl font-semibold text-[var(--fg-primary)]">
              Analyst Revise
            </div>
            <div className="text-xs text-[var(--fg-secondary)]">
              Draft ID: {activeReport.id.slice(0, 8)}...
            </div>
          </div>
          <Link
            href="/reports"
            className="text-sm text-[var(--fg-secondary)] hover:text-[var(--fg-primary)]"
          >
            Back to Reports
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-5xl space-y-6 px-6 py-8">
        {/* Basic Information Section */}
        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Basic Information
          </h2>

          <Textarea
            label="Report Title"
            value={formTitle}
            onChange={(event) => setFormTitle(event.target.value)}
            error={formErrors.title}
            disabled={!canEdit}
            rows={3}
          />

          <Select
            label="Report Type"
            value={formReportType}
            onChange={(event) =>
              setFormReportType(event.target.value as ReportType)
            }
            options={reportTypeOptions}
            error={formErrors.report_type}
            disabled={!canEdit}
          />

          {isCompanyType(formReportType) ? (
            <SearchableSelect
              label="Ticker"
              value={formTicker}
              onChange={setFormTicker}
              placeholder="Search ticker..."
              disabled={!canEdit}
              options={[
                { value: "", label: "" },
                ...coverages
                  .filter((c) => c.analysts.length > 0)
                  .map((c) => {
                    const firstAnalyst = [...c.analysts].sort(
                      (a, b) => a.author_order - b.author_order,
                    )[0];
                    const analystName =
                      firstAnalyst?.analyst?.english_name ?? "Unknown";
                    return {
                      value: c.ticker,
                      label: `${c.ticker} - ${analystName}`,
                    };
                  }),
              ]}
            />
          ) : null}

          {formReportType === "company" ? (
            <>
              <Select
                label="Rating"
                value={formRating}
                onChange={(event) => setFormRating(event.target.value)}
                options={[
                  { value: "", label: "Select rating..." },
                  ...ratingOptions,
                ]}
                disabled={!canEdit}
              />
              <Input
                label="Target Price"
                type="number"
                min={0}
                step={0.01}
                value={formTargetPrice}
                onChange={(event) => {
                  const value = event.target.value;
                  if (value === "" || /^\d*\.?\d*$/.test(value)) {
                    setFormTargetPrice(value);
                  }
                }}
                disabled={!canEdit}
              />
            </>
          ) : null}

          {requiresRegion(formReportType) ? (
            <Select
              label="Region"
              value={formRegionCode}
              onChange={(event) => setFormRegionId(event.target.value)}
              options={[
                { value: "", label: "Select region..." },
                ...regions.map((item) => ({
                  value: item.code,
                  label: `${item.name_en} (${item.code})`,
                })),
              ]}
              disabled={!canEdit}
            />
          ) : null}

          {requiresSector(formReportType) ? (
            <Select
              label="Sector"
              value={formSectorId}
              onChange={(event) => setFormSectorId(event.target.value)}
              options={[
                { value: "", label: "Select sector..." },
                ...sectors.flatMap((parent) => [
                  {
                    value: parent.id,
                    label: `${parent.name_en}${parent.name_cn ? ` (${parent.name_cn})` : ""}`,
                  },
                  ...parent.children.map((child) => ({
                    value: child.id,
                    label: `\u00A0\u00A0\u00A0\u00A0${child.name_en}${child.name_cn ? ` (${child.name_cn})` : ""}`,
                  })),
                ]),
              ]}
              disabled={!canEdit}
            />
          ) : null}

          <Select
            label="Report Language"
            value={formLanguage}
            onChange={(event) =>
              setFormLanguage(event.target.value as ReportLanguage)
            }
            options={LANGUAGE_OPTIONS}
            disabled={!canEdit}
          />

          <div className="space-y-2 rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-medium text-[var(--fg-primary)]">
                Analyst
              </div>
              {canEdit ? (
                <Button type="button" variant="ghost" onClick={addAnalyst}>
                  Add Analyst
                </Button>
              ) : null}
            </div>
            {formAnalysts.length === 0 ? (
              <p className="text-sm text-[var(--fg-primary)]">No analyst assigned.</p>
            ) : (
              formAnalysts.map((item, index) => (
                <div
                  key={`${item.analyst_email}-${index}`}
                  className="grid grid-cols-12 gap-2"
                >
                  <div className="col-span-9">
                    <Select
                      value={item.analyst_email}
                      onChange={(event) =>
                        updateAnalyst(index, event.target.value)
                      }
                      options={getAnalystOptions(index)}
                      disabled={!canEdit}
                    />
                  </div>
                  <div className="col-span-1 flex items-center text-xs text-[var(--fg-secondary)]">
                    #{index + 1}
                  </div>
                  <div className="col-span-2">
                    {canEdit ? (
                      <Button
                        type="button"
                        variant="ghost"
                        className="w-full"
                        onClick={() => removeAnalyst(index)}
                      >
                        Remove
                      </Button>
                    ) : null}
                  </div>
                </div>
              ))
            )}
            {formErrors.analysts ? (
              <p className="text-xs text-red-500">{formErrors.analysts}</p>
            ) : null}
          </div>

          <SearchableSelect
            label="Contact Person"
            value={formContactPerson}
            onChange={setFormContactPerson}
            placeholder="Search analyst..."
            disabled={!canEdit}
            options={[
              { value: "", label: "Select contact person..." },
              ...analysts.map((a) => ({
                value: a.email,
                label: `${a.english_name ?? a.email} (${a.email})`,
              })),
            ]}
          />

          <RichTextEditor
            label="Investment Thesis"
            value={formInvestmentThesis}
            onChange={setFormInvestmentThesis}
            minHeight="150px"
            readOnly={!canEdit}
          />

          {activeReport.translated_from_report_id && (
            <div className="mt-4 text-sm text-[var(--fg-secondary)]">
              This report is a translation. To view the original version, please{" "}
              <button
                type="button"
                onClick={() => {
                  const baseUrl = window.location.origin;
                  window.open(
                    `${baseUrl}/reports/${activeReport.translated_from_report_id}/edit`,
                    "_blank",
                    "noopener,noreferrer"
                  );
                }}
                className="text-blue-500 hover:underline"
              >
                click the link
              </button>
              .
            </div>
          )}
        </section>

        {/* Report Files Section */}
        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Files
          </h2>

          {/* Existing Files */}
          {activeReport.word_path ||
          activeReport.pdf_path ||
          activeReport.model_path ||
          activeReport.chief_approval_path ||
          activeReport.source_path ? (
            <div className="space-y-2">
              {/* Source File - 显示在最上面 */}
              {activeReport.source_path ? (
                <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        activeReport.source_path!,
                        activeReport.source_filename ?? activeReport.source_path!.split("/").pop() ?? "source",
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
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                    {activeReport.source_filename ?? activeReport.source_path!.split("/").pop()}
                  </button>
                </div>
              ) : null}

              {activeReport.word_path ? (
                <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        activeReport.word_path!,
                        activeReport.word_path!.split("/").pop() ?? "report",
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
                    {activeReport.word_path.split("/").pop()}
                  </button>
                </div>
              ) : null}

              {activeReport.pdf_path ? (
                <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        activeReport.pdf_path!,
                        activeReport.pdf_path!.split("/").pop() ?? "report.pdf",
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
                    {activeReport.pdf_path.split("/").pop()}
                  </button>
                </div>
              ) : null}

              {activeReport.model_path ? (
                <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        activeReport.model_path!,
                        // 优先使用原始文件名（含中文等），否则回退到 path 最后一段
                        activeReport.model_filename ?? activeReport.model_path!.split("/").pop() ?? "model",
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
                    {activeReport.model_filename ?? activeReport.model_path.split("/").pop()}
                  </button>
                </div>
              ) : null}

              {activeReport.chief_approval_path ? (
                <div className="rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-3">
                  <button
                    type="button"
                    className="flex items-center gap-2 text-sm text-blue-500 hover:underline"
                    onClick={() =>
                      handleDownload(
                        activeReport.chief_approval_path!,
                        activeReport.chief_approval_path!.split("/").pop() ?? "chief-approval",
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
                    {activeReport.chief_approval_path.split("/").pop()}
                  </button>
                </div>
              ) : null}
            </div>
          ) : null}

          {/* Upload Areas */}
          <FileDropzone
            label="Report File (Word/PPT)"
            accept=".doc,.docx,.ppt,.pptx"
            file={reportFile}
            onFileChange={setReportFile}
            disabled={!canEdit}
            hint="Supports .doc/.docx/.ppt/.pptx"
          />

          <FileDropzone
            label="Report Pdf (PDF)"
            accept=".pdf"
            file={pdfFile}
            onFileChange={setPdfFile}
            disabled={!canEdit}
            hint="Supports .pdf"
          />

          <FileDropzone
            label="Model File"
            accept=".xls,.xlsx,.csv"
            file={modelFile}
            onFileChange={setModelFile}
            disabled={!canEdit}
            hint={
              requiresModel(formReportType)
                ? "Required for Company report on submit"
                : "Optional for non-Company reports"
            }
          />

          <FileDropzone
            label="Source File (Original Report)"
            accept=".doc,.docx,.ppt,.pptx"
            file={sourceFile}
            onFileChange={setSourceFile}
            disabled={!canEdit}
            hint="Original report file (Word/PPT). Filename with Chinese characters will be preserved for download."
          />

          <FileDropzone
            label="Chief Approval"
            accept=".jpg,.jpeg,.png,.gif,.webp,.bmp"
            file={chiefApprovalFile}
            onFileChange={setChiefApprovalFile}
            disabled={!canEdit}
            hint="Optional image file for chief approval"
          />
        </section>

        {/* Status History Section */}
        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Status History
          </h2>
          {activeReport.status_logs.length === 0 ? (
            <p className="text-sm text-[var(--fg-tertiary)]">No history yet.</p>
          ) : (
            <div className="space-y-2">
              {activeReport.status_logs.map((item) => (
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
                  {(item.metadata.word_path || item.metadata.pdf_path || item.metadata.model_path || getChiefApprovalPath(item) || getSourcePath(item)) ? (
                    <div className="mt-2 space-y-1">
                      {/* 显示当前 report 的 source 信息（draft -> submitted 节点优先显示当前值） */}
                  {getSourcePath(item) ? (
                    <button
                      type="button"
                      className="flex items-center gap-1 text-xs text-blue-500 hover:underline"
                      onClick={() => {
                        const path = getSourcePath(item)!;
                        const filename = getSourceFilename(item) ?? path.split("/").pop() ?? "source";
                        handleDownload(path, filename);
                      }}
                    >
                      <svg className="h-3 w-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      {getSourceFilename(item) ?? getSourcePath(item)!.split("/").pop()}
                    </button>
                  ) : null}
                      {item.metadata.word_path ? (
                        <button
                          type="button"
                          className="flex items-center gap-1 text-xs text-blue-500 hover:underline"
                          onClick={() => handleDownload(item.metadata.word_path!, item.metadata.word_path!.split("/").pop() ?? "report.docx")}
                        >
                          <svg className="h-3 w-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          {item.metadata.word_path.split("/").pop()}
                        </button>
                      ) : null}
                      {item.metadata.pdf_path ? (
                        <button
                          type="button"
                          className="flex items-center gap-1 text-xs text-blue-500 hover:underline"
                          onClick={() => handleDownload(item.metadata.pdf_path!, item.metadata.pdf_path!.split("/").pop() ?? "report.pdf")}
                        >
                          <svg className="h-3 w-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          {item.metadata.pdf_path.split("/").pop()}
                        </button>
                      ) : null}
                      {item.metadata.model_path ? (
                        <button
                          type="button"
                          className="flex items-center gap-1 text-xs text-blue-500 hover:underline"
                          onClick={() => {
                            const path = item.metadata.model_path!;
                            // 优先使用 log metadata 中的原始文件名（含中文等），否则回退
                            const filename =
                              (item.metadata.model_filename as string | null | undefined) ??
                              path.split("/").pop() ??
                              "model.xlsx";
                            handleDownload(path, filename);
                          }}
                        >
                          <svg className="h-3 w-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          {(item.metadata.model_filename as string | null | undefined) ??
                            item.metadata.model_path.split("/").pop()}
                        </button>
                      ) : null}
                      {getChiefApprovalPath(item) ? (
                        <button
                          type="button"
                          className="flex items-center gap-1 text-xs text-blue-500 hover:underline"
                          onClick={() => {
                            const path = getChiefApprovalPath(item)!;
                            handleDownload(path, path.split("/").pop() ?? "chief-approval");
                          }}
                        >
                          <svg className="h-3 w-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          {getChiefApprovalPath(item)!.split("/").pop()}
                        </button>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Action Buttons */}
        <div className="flex justify-end gap-3">
          {canEdit ? (
            <>
              <Button
                type="button"
                variant="secondary"
                onClick={handleSaveDraft}
                isLoading={saving}
              >
                Save Draft
              </Button>
              {canSubmit ? (
                <Button type="button" onClick={handleSubmit} isLoading={saving}>
                  Submit
                </Button>
              ) : null}
            </>
          ) : (
            <Link href="/reports">
              <Button type="button" variant="secondary">
                Back to Reports
              </Button>
            </Link>
          )}
        </div>
      </main>
    </div>
  );
}
