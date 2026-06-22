"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Pagination } from "@/components/ui/pagination";
import { Select } from "@/components/ui/select";
import { Table, TD, TH, THead, TR } from "@/components/ui/table";
import { isReportTerminal, type ReportStatus } from "@/domain/schemas/report";
import type { ReportSummary } from "@/features/reports/repo/reports-repo";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";
import { terminateReportAction } from "@/features/reports/actions";

const STATUS_OPTIONS: { value: string; label: string }[] = [
  { value: "all", label: "All" },
  { value: "draft", label: "Draft" },
  { value: "submitted", label: "Submitted" },
  { value: "published", label: "Published" },
  { value: "rejected", label: "Rejected" },
  { value: "terminated", label: "Terminated" },
];

function statusTone(
  status: ReportStatus,
): "secondary" | "blue" | "green" | "red" {
  if (status === "draft") return "secondary";
  if (status === "submitted") return "blue";
  if (status === "published") return "green";
  if (status === "terminated") return "red";
  return "red";
}

function toQueryString(params: { q: string; status: string; page: number }) {
  const sp = new URLSearchParams();
  if (params.q.trim()) {
    sp.set("query", params.q.trim());
  }
  if (params.status && params.status !== "all") {
    sp.set("status", params.status);
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

export interface ReportsPageClientProps {
  reports: ReportSummary[];
  total: number;
  page: number;
  totalPages: number;
  currentQuery: string | null;
  currentStatus: ReportStatus | null;
  currentReportType: string | null;
  currentSubmittedBy: string | null;
  currentAnalyst: string | null;
  analysts: Analyst[];
  reportTypes: string[];
  userRole: "admin" | "sa" | "analyst";
  currentUserId: string;
}

export function ReportsPageClient({
  reports,
  total: _total,
  page,
  totalPages,
  currentQuery,
  currentStatus,
  currentReportType,
  currentSubmittedBy,
  currentAnalyst,
  analysts,
  reportTypes,
  userRole,
  currentUserId,
}: ReportsPageClientProps) {
  const router = useRouter();

  const canCreate = userRole === "admin" || userRole === "analyst";
  const [queryDraft, setQueryDraft] = React.useState(currentQuery ?? "");
  const defaultStatus = "all";
  const [statusFilter, setStatusFilter] = React.useState<string | null>(
    currentStatus ?? defaultStatus,
  );
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
    setStatusFilter(currentStatus ?? "all");
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
    router.push(`/reports${buildQueryString({ page: nextPage })}`);
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    goToPage(1);
  }

  function onStatusChange(value: string) {
    setStatusFilter(value as ReportStatus | "all");
    router.push(`/reports${buildQueryString({ status: value, page: 1 })}`);
  }

  function onReportTypeChange(value: string) {
    setReportTypeFilter(value);
    router.push(`/reports${buildQueryString({ report_type: value, page: 1 })}`);
  }

  function onSubmittedByChange(value: string) {
    setSubmittedByFilter(value);
    router.push(`/reports${buildQueryString({ contact_person: value, page: 1 })}`);
  }

  function onAnalystChange(value: string) {
    setAnalystFilter(value);
    router.push(`/reports${buildQueryString({ analyst: value, page: 1 })}`);
  }

  function canEditReport(
    report: Pick<ReportSummary, "owner_user_id" | "status">,
  ): boolean {
    if (userRole === "admin") {
      return report.status === "draft" || report.status === "submitted";
    }
    if (userRole === "analyst") {
      return (
        report.owner_user_id === currentUserId &&
        (report.status === "draft" || report.status === "submitted")
      );
    }
    return false;
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
          <div className="text-xl font-semibold text-[var(--fg-primary)]">
            Analyst Revise
          </div>
          {canCreate ? (
            <Link
              href="/reports/new"
              className="inline-flex items-center justify-center rounded-[6px] bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors duration-200 hover:bg-blue-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/60"
            >
              Add Report
            </Link>
          ) : (
            <div />
          )}
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-4 px-6 py-8">
        <div className="flex items-end justify-between gap-4">
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
                value={statusFilter ?? "all"}
                onChange={(event) => onStatusChange(event.target.value)}
                options={STATUS_OPTIONS}
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
              <TH className="text-right">Actions</TH>
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
                    <div className="flex justify-end gap-2">
                      {(() => {
                        const terminal = isReportTerminal(report.status);
                        if (canEditReport(report)) {
                          return (
                            <Link href={`/reports/${report.id}/edit`}>
                              <Button variant="outline" className="h-7 px-2 text-xs">
                                Edit
                              </Button>
                            </Link>
                          );
                        }
                        // 不可编辑的报告路由规则：
                        //   - SA 始终走 /report-review/[id]（SA 是 review 角色）
                        //   - 终态（published/terminated）走 /report-review/[id] 只读视图
                        //   - 其他（analyst 查看 rejected 等）走 /reports/[id]/edit
                        let viewHref: string;
                        if (userRole === "sa") {
                          viewHref = `/report-review/${report.id}`;
                        } else if (terminal) {
                          viewHref = `/report-review/${report.id}`;
                        } else {
                          viewHref = `/reports/${report.id}/edit`;
                        }
                        return (
                          <Link href={viewHref}>
                            <Button variant="outline" className="h-7 px-2 text-xs">
                              View
                            </Button>
                          </Link>
                        );
                      })()}
                      {report.status !== "published" && report.status !== "terminated" && (
                        <Button
                          variant="outline"
                          className="h-7 px-2 text-xs text-red-600"
                          onClick={async () => {
                            if (!confirm("Terminate this report?")) return;
                            const result = await terminateReportAction(report.id);
                            if (result.ok) {
                              router.refresh();
                            } else {
                              alert(result.error);
                            }
                          }}
                        >
                          Terminate
                        </Button>
                      )}
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
