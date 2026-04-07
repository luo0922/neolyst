"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

import { ActionButton } from "@/components/ui/action-button";
import { Button } from "@/components/ui/button";
import { ConfirmModal } from "@/components/ui/confirm-modal";
import { FileDropzone } from "@/components/ui/file-dropzone";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Select } from "@/components/ui/select";
import { useToast } from "@/components/ui/toast";
import { formatShanghaiYmd } from "@/lib/time";
import {
  createTemplateAction,
  deleteTemplateAction,
  uploadTemplateFileAction,
} from "../actions";
import type {
  TemplateGroup,
  ReportType,
  Language,
} from "../repo/templates-repo";

export interface TemplatesPageClientProps {
  templateGroups: TemplateGroup[];
  reportTypes: string[];
}

const REPORT_TYPE_LABELS: Record<ReportType, string> = {
  company: "Company",
  sector: "Sector",
  company_flash: "Company Flash",
  sector_flash: "Sector Flash",
  macro: "Macro",
  strategy: "Strategy",
  quantitative: "Quantitative",
  bond: "Bond",
};

const LANGUAGE_LABELS: Record<Language, string> = {
  en: "English",
  zh: "Chinese",
};

export function TemplatesPageClient({
  templateGroups,
  reportTypes,
}: TemplatesPageClientProps) {
  const router = useRouter();
  const toast = useToast();

  // Upload modal
  const [uploadOpen, setUploadOpen] = React.useState(false);
  const [uploadReportType, setUploadReportType] =
    React.useState<ReportType>("company");
  const [uploadLanguage, setUploadLanguage] = React.useState<Language>("en");
  const [uploadName, setUploadName] = React.useState("");
  const [uploadTemplateFile, setUploadTemplateFile] = React.useState<File | null>(null);
  const [uploadSchemaFile, setUploadSchemaFile] = React.useState<File | null>(null);
  const [uploadLoading, setUploadLoading] = React.useState(false);
  const [uploadErrors, setUploadErrors] = React.useState<
    Record<string, string>
  >({});

  // Delete confirm
  const [deleteOpen, setDeleteOpen] = React.useState(false);
  const [deleteId, setDeleteId] = React.useState<string | null>(null);
  const [deleteLoading, setDeleteLoading] = React.useState(false);

  function openUpload(reportType?: ReportType, language?: Language) {
    // Collect all available report types from both sources
    const existingTypes = templateGroups.map(g => g.report_type);
    const allTypes = [...new Set([...reportTypes, ...existingTypes])];
    const defaultType = reportType ?? (allTypes.length > 0 ? allTypes[0] : "company");
    setUploadReportType(defaultType as ReportType);
    setUploadLanguage(language ?? "en");
    setUploadName("");
    setUploadTemplateFile(null);
    setUploadSchemaFile(null);
    setUploadErrors({});
    setUploadOpen(true);
  }

  async function submitUpload(e: React.FormEvent) {
    e.preventDefault();

    const name = uploadName.trim();
    if (!name) {
      setUploadErrors({ name: "Name is required" });
      return;
    }
    if (!uploadTemplateFile) {
      setUploadErrors({ template_file: "Template file is required" });
      return;
    }

    // Validate file type (.doc/.docx only)
    const validExtensions = [".docx", ".doc"];
    const fileExt = uploadTemplateFile.name
      .toLowerCase()
      .slice(uploadTemplateFile.name.lastIndexOf("."));
    if (!validExtensions.includes(fileExt)) {
      setUploadErrors({
        template_file: `Invalid file type. Expected ${validExtensions.join(" or ")}`,
      });
      return;
    }

    // Validate schema file if provided
    if (uploadSchemaFile) {
      const schemaExt = uploadSchemaFile.name
        .toLowerCase()
        .slice(uploadSchemaFile.name.lastIndexOf("."));
      if (schemaExt !== ".json") {
        setUploadErrors({
          schema_file: "Schema file must be a JSON file",
        });
        return;
      }
    }

    setUploadLoading(true);
    setUploadErrors({});

    try {
      // Upload template file
      const templateFd = new FormData();
      templateFd.append("file", uploadTemplateFile);
      templateFd.append("reportType", uploadReportType);
      templateFd.append("fileKind", "template");

      const templateResult = await uploadTemplateFileAction(templateFd);
      if (!templateResult.ok) {
        toast.error(templateResult.error, { title: "Error" });
        setUploadLoading(false);
        return;
      }

      let schemaFilePath: string | null | undefined = undefined;

      // Upload schema file if provided
      if (uploadSchemaFile) {
        const schemaFd = new FormData();
        schemaFd.append("file", uploadSchemaFile);
        schemaFd.append("reportType", uploadReportType);
        schemaFd.append("fileKind", "schema");

        const schemaResult = await uploadTemplateFileAction(schemaFd);
        if (!schemaResult.ok) {
          toast.error(schemaResult.error, { title: "Error" });
          setUploadLoading(false);
          return;
        }
        schemaFilePath = schemaResult.file_path;
      }

      const res = await createTemplateAction({
        name,
        report_type: uploadReportType,
        language: uploadLanguage,
        template_file_path: templateResult.file_path,
        schema_file_path: schemaFilePath,
      });

      if (!res.ok) {
        toast.error(res.error, { title: "Error" });
        setUploadLoading(false);
        return;
      }

      setUploadOpen(false);
      toast.success("Template uploaded.", { title: "Success" });
      router.refresh();
    } catch {
      toast.error("Failed to upload template", { title: "Error" });
    } finally {
      setUploadLoading(false);
    }
  }

  function openDelete(templateId: string) {
    setDeleteId(templateId);
    setDeleteOpen(true);
  }

  async function confirmDelete() {
    if (!deleteId) return;

    setDeleteLoading(true);
    const res = await deleteTemplateAction(deleteId);
    setDeleteLoading(false);

    if (!res.ok) {
      toast.error(res.error, { title: "Error" });
      return;
    }

    setDeleteOpen(false);
    toast.success("Template deleted.", { title: "Success" });
    router.refresh();
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div className="text-xl font-semibold text-[var(--fg-primary)]">Templates</div>
          <Button onClick={() => openUpload()}>Upload Template</Button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-6 px-6 py-8">
        {templateGroups.length === 0 ? (
          <div className="rounded-lg border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/30 p-8 text-center">
            <p className="text-[var(--fg-secondary)]">No templates uploaded yet.</p>
            <Button className="mt-4" onClick={() => openUpload()}>
              Upload First Template
            </Button>
          </div>
        ) : (
          templateGroups.map((group) => (
            <div
              key={`${group.report_type}-${group.language}`}
              className="rounded-lg border border-[var(--border-subtle)] bg-[var(--bg-surface-hover)]/30"
            >
              <div className="flex items-center justify-between border-b border-[var(--border-subtle)] px-4 py-3">
                <div>
                  <span className="font-medium text-[var(--fg-primary)]">
                    {REPORT_TYPE_LABELS[group.report_type as ReportType] ?? group.report_type}
                  </span>
                  <span className="mx-2 text-[var(--fg-tertiary)]">/</span>
                  <span className="text-[var(--fg-secondary)]">
                    {LANGUAGE_LABELS[group.language]}
                  </span>
                  <span className="ml-3 rounded bg-[var(--bg-surface)]/80 px-2 py-0.5 text-xs text-[var(--fg-secondary)]">
                    {group.templates.length} version{group.templates.length !== 1 ? "s" : ""}
                  </span>
                </div>
                <Button
                  variant="ghost"
                  onClick={() =>
                    openUpload(
                      group.report_type as ReportType,
                      group.language,
                    )
                  }
                  className="text-xs px-2 py-1"
                >
                  Upload New Version
                </Button>
              </div>

              {/* Template versions list */}
              {group.templates.length === 0 ? (
                <div className="px-4 py-3 text-[var(--fg-secondary)]">
                  No template versions yet.
                </div>
              ) : (
                <div className="divide-y divide-white/5">
                  {group.templates.map((template) => (
                    <div
                      key={template.id}
                      className="flex items-center justify-between px-4 py-3 hover:bg-white/5"
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-[var(--fg-primary)]">
                          {template.name}
                        </span>
                        <span className="rounded bg-[var(--bg-surface)] px-1.5 py-0.5 text-xs text-[var(--fg-secondary)]">
                          v{template.version}
                        </span>
                        {template.schema_file_path && (
                          <span className="rounded bg-blue-500/20 px-1.5 py-0.5 text-xs text-blue-300">
                            Schema
                          </span>
                        )}
                        <span className="text-sm text-[var(--fg-tertiary)]">
                          {formatShanghaiYmd(template.created_at)}
                        </span>
                      </div>
                      <ActionButton
                        tone="danger"
                        onClick={() => openDelete(template.id)}
                      >
                        Delete
                      </ActionButton>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))
        )}
      </main>

      <Modal
        open={uploadOpen}
        title="Upload Template"
        onClose={() => setUploadOpen(false)}
        footer={
          <>
            <Button
              variant="ghost"
              type="button"
              onClick={() => setUploadOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" form="upload-form" isLoading={uploadLoading}>
              Upload
            </Button>
          </>
        }
      >
        <form id="upload-form" className="space-y-3" onSubmit={submitUpload}>
          <div className="grid grid-cols-2 gap-3">
            <Select
              label="Report Type"
              value={uploadReportType}
              onChange={(e) =>
                setUploadReportType(e.target.value as ReportType)
              }
              options={(() => {
                const existingTypes = templateGroups.map(g => g.report_type);
                const allTypes = [...new Set([...reportTypes, ...existingTypes])];
                if (allTypes.length === 0) {
                  return [
                    { value: "company", label: "company" },
                    { value: "sector", label: "sector" },
                    { value: "macro", label: "macro" },
                    { value: "strategy", label: "strategy" },
                  ];
                }
                return allTypes.map((rt) => ({ value: rt, label: rt }));
              })()}
            />
            <Select
              label="Language"
              value={uploadLanguage}
              onChange={(e) => setUploadLanguage(e.target.value as Language)}
              options={[
                { value: "en", label: "English" },
                { value: "zh", label: "Chinese" },
              ]}
            />
          </div>
          <Input
            label="Template Name"
            placeholder="e.g., Company Report Template v1"
            value={uploadName}
            onChange={(e) => setUploadName(e.target.value)}
            error={uploadErrors.name}
          />
          <div className="space-y-1.5">
            <FileDropzone
              label="Template File"
              accept=".docx,.doc"
              file={uploadTemplateFile}
              onFileChange={setUploadTemplateFile}
              error={uploadErrors.template_file}
              hint="Supports .doc/.docx"
            />
          </div>
          <div className="space-y-1.5">
            <FileDropzone
              label="Schema File (Optional)"
              accept=".json"
              file={uploadSchemaFile}
              onFileChange={setUploadSchemaFile}
              error={uploadErrors.schema_file}
              hint="JSON file describing required fields and their positions"
            />
          </div>
        </form>
      </Modal>

      <ConfirmModal
        open={deleteOpen}
        title="Delete template?"
        description="This action cannot be undone."
        onClose={() => setDeleteOpen(false)}
        onConfirm={confirmDelete}
        confirmTone="danger"
        confirmLabel="Delete"
        loading={deleteLoading}
      />
    </div>
  );
}
