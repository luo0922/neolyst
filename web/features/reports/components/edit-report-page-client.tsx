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
  saveReportContentAction,
  submitReportAction,
  uploadReportFileAction,
} from "@/features/reports/actions";
import {
  validateUploadExtension,
  validateWordPptExtension,
  validatePdfExtension,
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
      (activeReport.status === "draft" || activeReport.status === "submitted"));

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
        };
      }
    | { ok: false; error: string }
  > {
    const reportId = activeReport.id;

    let wordPath: string | null = activeReport?.word_path ?? null;
    let pdfPath: string | null = activeReport?.pdf_path ?? null;
    let modelPath: string | null = activeReport?.model_path ?? null;

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
    }

    return {
      ok: true,
      data: {
        word_path: wordPath,
        pdf_path: pdfPath,
        model_path: modelPath,
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
      });

      if (!saveResult.ok) {
        toast.error(saveResult.error, { title: "Error" });
        return;
      }

      setActiveReport(saveResult.data);
      setReportFile(null);
      setPdfFile(null);
      setModelFile(null);
      toast.success("Draft saved.", { title: "Success" });
      router.refresh();
    } finally {
      setSaving(false);
    }
  }

  async function handleSubmit() {
    if (!activeReport) {
      toast.error("Please save draft first.", { title: "Error" });
      return;
    }

    setSaving(true);
    try {
      const submitResult = await submitReportAction({
        report_id: activeReport.id,
      });
      if (!submitResult.ok) {
        toast.error(submitResult.error, { title: "Error" });
        return;
      }

      setActiveReport(submitResult.data);
      toast.success("Report submitted.", { title: "Success" });
      router.refresh();
    } finally {
      setSaving(false);
    }
  }

  async function handleDirectSubmit() {
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
      });

      if (!directResult.ok) {
        toast.error(directResult.error, { title: "Error" });
        return;
      }

      setActiveReport(directResult.data);
      setReportFile(null);
      setPdfFile(null);
      setModelFile(null);
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
          />
        </section>

        {/* Report Files Section */}
        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Files
          </h2>

          {/* Existing Files */}
          {activeReport.word_path ||
          activeReport.pdf_path ||
          activeReport.model_path ? (
            <div className="space-y-2">
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
                    Report File
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
                    PDF File
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
                        activeReport.model_path!.split("/").pop() ?? "model",
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
              {canSubmit ? (
                <Button
                  type="button"
                  onClick={handleDirectSubmit}
                  isLoading={saving}
                >
                  Direct Submit
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
