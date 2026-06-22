"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Pagination } from "@/components/ui/pagination";
import { Select } from "@/components/ui/select";
import { Table, TD, TH, THead, TR } from "@/components/ui/table";
import type {
  ReportSummary,
} from "@/features/reports/repo/reports-repo";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";

export interface ReportReviewPageClientProps {
  reports: ReportSummary[];
  total: number;
  page: number;
  totalPages: number;
  currentQuery: string | null;
  currentStatus: "all" | "submitted" | "published" | "rejected" | "terminated";
  currentReportType: string | null;
  currentSubmittedBy: string | null;
  currentAnalyst: string | null;
  analysts: Analyst[];
  reportTypes: string[];
  currentUserId: string;
}

const FILTER_OPTIONS = [
  { value: "all", label: "All" },
  { value: "submitted", label: "Submitted" },
  { value: "published", label: "Published" },
  { value: "rejected", label: "Rejected" },
  { value: "terminated", label: "Terminated" },
];

function statusTone(status: string): "blue" | "green" | "red" {
  if (status === "submitted") return "blue";
  if (status === "published") return "green";
  if (status === "terminated") return "red";
  return "red";
}

function toQueryString(params: { q: string; status: string; page: number; report_type?: string; submitted_by?: string; contact_person?: string; analyst?: string }) {
  const sp = new URLSearchParams();
  if (params.q.trim()) {
    sp.set("query", params.q.trim());
  }
  if (params.status && params.status !== "all") {
    sp.set("status", params.status);
  }
  if (params.report_type) {
    sp.set("report_type", params.report_type);
  }
  if (params.submitted_by) {
    sp.set("submitted_by", params.submitted_by);
  }
  if (params.contact_person) {
    sp.set("contact_person", params.contact_person);
  }
  if (params.analyst) {
    sp.set("analyst", params.analyst);
  }
  if (params.page > 1) {
    sp.set("page", String(params.page));
  }
  const value = sp.toString();
  return value ? `?${value}` : "";
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

export function ReportReviewPageClient({
  reports,
  total,
  page,
  totalPages,
  currentQuery,
  currentStatus,
  currentReportType,
  currentSubmittedBy,
  currentAnalyst,
  analysts,
  reportTypes,
  currentUserId,
}: ReportReviewPageClientProps) {
  const router = useRouter();

  const [queryDraft, setQueryDraft] = React.useState(currentQuery ?? "");
  const [statusFilter, setStatusFilter] = React.useState(currentStatus);
  const [reportTypeFilter, setReportTypeFilter] = React.useState(currentReportType ?? "");
  const [submittedByFilter, setSubmittedByFilter] = React.useState(currentSubmittedBy ?? "");
  const [analystFilter, setAnalystFilter] = React.useState(currentAnalyst ?? "");

  // Build report_type dropdown options from the full list of active report types
  const reportTypeOptions = React.useMemo(() => {
    return [
      { value: "", label: "All types" },
      ...reportTypes.map((t) => ({ value: t, label: t })),
    ];
  }, [reportTypes]);

  React.useEffect(() => {
    setQueryDraft(currentQuery ?? "");
    setStatusFilter(currentStatus);
    setReportTypeFilter(currentReportType ?? "");
    setSubmittedByFilter(currentSubmittedBy ?? "");
    setAnalystFilter(currentAnalyst ?? "");
  }, [currentQuery, currentStatus, currentReportType, currentSubmittedBy, currentAnalyst]);

  function buildQueryString(overrides?: Partial<{ q: string; status: string; page: number; report_type: string; contact_person: string; analyst: string }>) {
    const sp = new URLSearchParams();
    const q = overrides?.q ?? queryDraft;
    const status = overrides?.status ?? statusFilter ?? "all";
    const rt = overrides?.report_type ?? reportTypeFilter;
    const cp = overrides?.contact_person ?? submittedByFilter;
    const an = overrides?.analyst ?? analystFilter;

    if (q.trim()) {
      sp.set("query", q.trim());
    }
    if (status && status !== "all") {
      sp.set("status", status);
    }
    if (rt) {
      sp.set("report_type", rt);
    }
    if (cp) {
      sp.set("contact_person", cp);
    }
    if (an) {
      sp.set("analyst", an);
    }
    const page = overrides?.page ?? 1;
    if (page > 1) {
      sp.set("page", String(page));
    }
    const value = sp.toString();
    return value ? `?${value}` : "";
  }

  function goToPage(nextPage: number) {
    router.push(
      `/report-review${buildQueryString({ page: nextPage })}`,
    );
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    goToPage(1);
  }

  function onStatusChange(value: "all" | "submitted" | "published" | "rejected") {
    setStatusFilter(value);
    router.push(
      `/report-review${buildQueryString({ status: value, page: 1 })}`,
    );
  }

  function onReportTypeChange(value: string) {
    setReportTypeFilter(value);
    router.push(`/report-review${buildQueryString({ report_type: value, page: 1 })}`);
  }

  function onSubmittedByChange(value: string) {
    setSubmittedByFilter(value);
    router.push(`/report-review${buildQueryString({ contact_person: value, page: 1 })}`);
  }

  function onAnalystChange(value: string) {
    setAnalystFilter(value);
    router.push(`/report-review${buildQueryString({ analyst: value, page: 1 })}`);
  }

  function getAnalystNames(analysts: ReportSummary["analysts"]): string {
    return analysts
      .sort((a, b) => a.author_order - b.author_order)
      .map((a) => a.english_name ?? a.analyst_email)
      .join(", ");
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div>
            <div className="text-xl font-semibold text-[var(--fg-primary)]">
              Quality Review
            </div>
            <div className="text-xs text-[var(--fg-secondary)]">Total {total}</div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-4 px-6 py-8">
        <div className="flex items-end gap-4">
          <form className="flex flex-1 gap-4 flex-wrap" onSubmit={submitSearch}>
            <div className="w-full max-w-md">
              <Input
                label="Search"
                placeholder="Search by title"
                value={queryDraft}
                onChange={(event) => setQueryDraft(event.target.value)}
              />
            </div>
            <div className="w-40">
              <Select
                label="Status"
                value={statusFilter}
                onChange={(event) =>
                  onStatusChange(
                    event.target.value as
                      | "all"
                      | "submitted"
                      | "published"
                      | "rejected",
                  )
                }
                options={FILTER_OPTIONS}
              />
            </div>
            <div className="w-40">
              <Select
                label="Type"
                value={reportTypeFilter}
                onChange={(event) => onReportTypeChange(event.target.value)}
                options={reportTypeOptions}
              />
            </div>
            <div className="w-48">
              <Select
                label="Submitted by"
                value={submittedByFilter}
                onChange={(event) => onSubmittedByChange(event.target.value)}
                options={[
                  { value: "", label: "All analysts" },
                  ...analysts.map((a) => ({
                    value: a.email,
                    label: a.english_name ?? a.email,
                  })),
                ]}
              />
            </div>
            <div className="w-48">
              <Select
                label="Analysts"
                value={analystFilter}
                onChange={(event) => onAnalystChange(event.target.value)}
                options={[
                  { value: "", label: "All analysts" },
                  ...analysts.map((a) => ({
                    value: a.email,
                    label: a.english_name ?? a.email,
                  })),
                ]}
              />
            </div>
          </form>
        </div>

        <Table>
<THead>
            <TR>
              <TH className="w-full">Title</TH>
              <TH className="whitespace-nowrap">Type</TH>
              <TH className="whitespace-nowrap">Rating</TH>
              <TH className="whitespace-nowrap">Target price</TH>
              <TH className="whitespace-nowrap">Status</TH>
              <TH className="whitespace-nowrap">Owner</TH>
              <TH className="whitespace-nowrap">Submitter</TH>
              <TH className="whitespace-nowrap">Analysts</TH>
              <TH className="whitespace-nowrap">Updated</TH>
              <TH className="text-right">Action</TH>
            </TR>
          </THead>
          <tbody>
            {reports.length === 0 ? (
              <TR>
                <TD colSpan={10} className="py-10 text-center text-[var(--fg-secondary)]">
                  No reports found.
                </TD>
              </TR>
            ) : (
              reports.map((report) => {
                const isCompanyReport =
                  report.report_type === "company" ||
                  report.report_type === "company_flash" ||
                  report.report_type === "company-translate";
                return (
                <TR key={report.id}>
                  <TD className="font-medium text-[var(--fg-primary)]">{report.title}</TD>
                  <TD className="text-[var(--fg-secondary)]">{report.report_type}</TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {isCompanyReport && report.rating ? report.rating : "-"}
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {isCompanyReport && report.target_price ? report.target_price : "-"}
                  </TD>
                  <TD>
                    <Badge tone={statusTone(report.status)}>
                      {report.status}
                    </Badge>
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {report.owner_user_id === currentUserId
                      ? "Me"
                      : report.owner_name ?? `${report.owner_user_id.slice(0, 8)}...`}
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {report.contact_person_name ?? report.contact_person ?? "-"}
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {getAnalystNames(report.analysts)}
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {formatDateTime(report.updated_at)}
                  </TD>
                  <TD>
                    <div className="flex justify-end">
                      <Link href={`/report-review/${report.id}`}>
                        <Button type="button" variant="secondary">
                          Review
                        </Button>
                      </Link>
                    </div>
                  </TD>
                </TR>
                );
              })
            )}
          </tbody>
        </Table>

        <Pagination page={page} totalPages={totalPages} onChange={goToPage} />
      </main>

    </div>
  );
}
