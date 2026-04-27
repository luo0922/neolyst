"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { FileDropzone } from "@/components/ui/file-dropzone";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select } from "@/components/ui/select";
import { SearchableSelect } from "@/components/ui/searchable-select";
import { RichTextEditor } from "@/components/ui/rich-text-editor";
import { useToast } from "@/components/ui/toast";
import type {
  ReportAnalystInput,
  ReportLanguage,
} from "@/domain/schemas/report";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";
import type { CoverageWithDetails } from "@/features/coverage/repo/coverage-repo";
import type { Region } from "@/features/regions/repo/regions-repo";
import type { Rating } from "@/features/ratings/repo/ratings-repo";
import type { SectorWithChildren } from "@/features/sectors/repo/sectors-repo";
import {
  createReportAction,
  directSubmitReportAction,
  saveReportContentAction,
  uploadReportFileAction,
} from "@/features/reports/actions";
import {
  validateUploadExtension,
  validateWordPptExtension,
  validatePdfExtension,
} from "@/features/reports/file-utils";
import type { ReportDetail } from "@/features/reports/repo/reports-repo";
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

export interface NewReportPageClientProps {
  userRole: "admin" | "analyst";
  reportTypes: string[];
  analysts: Analyst[];
  regions: Region[];
  sectors: SectorWithChildren[];
  coverages: CoverageWithDetails[];
  ratings: Rating[];
}

export function NewReportPageClient({
  userRole,
  reportTypes,
  analysts,
  regions,
  sectors,
  coverages,
  ratings,
}: NewReportPageClientProps) {
  const router = useRouter();
  const toast = useToast();

  const canCreate = userRole === "admin" || userRole === "analyst";
  const [activeReport, setActiveReport] = React.useState<ReportDetail | null>(
    null,
  );
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

  const [formTitle, setFormTitle] = React.useState("");
  const [formReportType, setFormReportType] = React.useState(
    reportTypes[0] ?? "company",
  );
  const [formTicker, setFormTicker] = React.useState("");
  const [formRating, setFormRating] = React.useState("");
  const [formTargetPrice, setFormTargetPrice] = React.useState("");
  const [formRegionCode, setFormRegionCode] = React.useState("");
  const [formSectorId, setFormSectorId] = React.useState("");
  const [formLanguage, setFormLanguage] = React.useState<ReportLanguage>("en");
  const [formContactPerson, setFormContactPerson] = React.useState("");
  const [formInvestmentThesis, setFormInvestmentThesis] = React.useState("");
  const [formAnalysts, setFormAnalysts] = React.useState<ReportAnalystInput[]>(
    [],
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
        .filter((item) => item.email === current || !selectedOthers.has(item.email))
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

  async function ensureReportId(
    analystsValue: ReportAnalystInput[],
  ): Promise<ReportDetail | null> {
    if (activeReport) {
      return activeReport;
    }

    const createResult = await createReportAction({
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
    });

    if (!createResult.ok) {
      toast.error(createResult.error, { title: "Error" });
      return null;
    }

    setActiveReport(createResult.data);
    return createResult.data;
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
    const reportId = activeReport?.id;
    if (!reportId) {
      return { ok: false, error: "No active report" };
    }

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
    if (!canCreate) {
      toast.error("No permission", { title: "Error" });
      return;
    }

    const analystsValue = validateForm();
    if (!analystsValue) {
      return;
    }

    setSaving(true);
    try {
      const ensuredReport = await ensureReportId(analystsValue);
      if (!ensuredReport) {
        return;
      }

      const uploadResult = await uploadReportFiles();
      if (!uploadResult.ok) {
        toast.error(uploadResult.error, { title: "Error" });
        return;
      }

      const saveResult = await saveReportContentAction({
        report_id: ensuredReport.id,
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

  async function handleDirectSubmit() {
    if (!canCreate) {
      toast.error("No permission", { title: "Error" });
      return;
    }

    const analystsValue = validateForm();
    if (!analystsValue) {
      return;
    }

    setSaving(true);
    try {
      const ensuredReport = await ensureReportId(analystsValue);
      if (!ensuredReport) {
        return;
      }

      const uploadResult = await uploadReportFiles();
      if (!uploadResult.ok) {
        toast.error(uploadResult.error, { title: "Error" });
        return;
      }

      const directResult = await directSubmitReportAction({
        report_id: ensuredReport.id,
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

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <div>
            <div className="text-xl font-semibold text-[var(--fg-primary)]">
              Analyst Submit
            </div>
            {activeReport ? (
              <div className="text-xs text-[var(--fg-secondary)]">
                Draft ID: {activeReport.id.slice(0, 8)}...
              </div>
            ) : null}
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
        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Basic Information
          </h2>

          <Textarea
            label="Report Title"
            value={formTitle}
            onChange={(event) => setFormTitle(event.target.value)}
            error={formErrors.title}
            rows={3}
          />

          <Select
            label="Report Type"
            value={formReportType}
            onChange={(event) => setFormReportType(event.target.value)}
            options={reportTypeOptions}
            error={formErrors.report_type}
          />

          {isCompanyType(formReportType) ? (
            <SearchableSelect
              label="Ticker"
              value={formTicker}
              onChange={setFormTicker}
              placeholder="Search ticker..."
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
              />
            </>
          ) : null}

          {requiresRegion(formReportType) ? (
            <Select
              label="Region"
              value={formRegionCode}
              onChange={(event) => setFormRegionCode(event.target.value)}
              options={[
                { value: "", label: "Select region..." },
                ...regions.map((item) => ({
                  value: item.code,
                  label: `${item.name_en} (${item.code})`,
                })),
              ]}
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
            />
          ) : null}

          <Select
            label="Report Language"
            value={formLanguage}
            onChange={(event) =>
              setFormLanguage(event.target.value as ReportLanguage)
            }
            options={LANGUAGE_OPTIONS}
          />

          <div className="space-y-2 rounded-[8px] border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/40 p-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-medium text-[var(--fg-primary)]">
                Analyst
              </div>
              <Button type="button" variant="ghost" onClick={addAnalyst}>
                Add Analyst
              </Button>
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
            {formErrors.analysts ? (
              <p className="text-xs text-red-500">{formErrors.analysts}</p>
            ) : null}
          </div>

          <SearchableSelect
            label="Contact Person"
            value={formContactPerson}
            onChange={setFormContactPerson}
            placeholder="Search analyst..."
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

        <section className="space-y-4 rounded-[12px] border border-[var(--border-subtle)] bg-[var(--bg-surface)]/70 p-5">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--fg-secondary)]">
            Report Files
          </h2>
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
            hint={
              requiresModel(formReportType)
                ? "Required for Company report on submit"
                : "Optional for non-Company reports"
            }
          />
        </section>

        <div className="flex justify-end gap-3">
          <Button
            type="button"
            variant="secondary"
            onClick={handleSaveDraft}
            isLoading={saving}
          >
            Save Draft
          </Button>
          <Button
            type="button"
            onClick={handleDirectSubmit}
            isLoading={saving}
          >
            Direct Submit
          </Button>
        </div>
      </main>
    </div>
  );
}
