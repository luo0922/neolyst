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

export interface ReportReviewPageClientProps {
  reports: ReportSummary[];
  total: number;
  page: number;
  totalPages: number;
  currentQuery: string | null;
  currentStatus: "all" | "submitted" | "published" | "rejected";
}

const FILTER_OPTIONS = [
  { value: "all", label: "All" },
  { value: "submitted", label: "Submitted" },
  { value: "published", label: "Published" },
  { value: "rejected", label: "Rejected" },
];

function statusTone(status: string): "blue" | "green" | "red" {
  if (status === "submitted") return "blue";
  if (status === "published") return "green";
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

export function ReportReviewPageClient({
  reports,
  total: _total,
  page,
  totalPages,
  currentQuery,
  currentStatus,
}: ReportReviewPageClientProps) {
  const router = useRouter();

  const [queryDraft, setQueryDraft] = React.useState(currentQuery ?? "");
  const [statusFilter, setStatusFilter] = React.useState(currentStatus);

  React.useEffect(() => {
    setQueryDraft(currentQuery ?? "");
    setStatusFilter(currentStatus);
  }, [currentQuery, currentStatus]);

  function goToPage(nextPage: number) {
    router.push(
      `/report-review${toQueryString({
        q: queryDraft,
        status: statusFilter,
        page: nextPage,
      })}`,
    );
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    goToPage(1);
  }

  function onStatusChange(value: "all" | "submitted" | "published" | "rejected") {
    setStatusFilter(value);
    router.push(
      `/report-review${toQueryString({ q: queryDraft, status: value, page: 1 })}`,
    );
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div>
            <div className="text-xl font-semibold text-[var(--fg-primary)]">
              Quality Review
            </div>
            <div className="text-xs text-[var(--fg-secondary)]">Total {reports.length}</div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-4 px-6 py-8">
        <div className="flex items-end gap-4">
          <form className="flex flex-1 gap-4" onSubmit={submitSearch}>
            <div className="w-full max-w-md">
              <Input
                label="Search"
                placeholder="Search by title"
                value={queryDraft}
                onChange={(event) => setQueryDraft(event.target.value)}
              />
            </div>
            <div className="w-56">
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
          </form>
        </div>

        <Table>
          <THead>
            <TR>
              <TH className="w-full">Title</TH>
              <TH className="whitespace-nowrap">Status</TH>
              <TH className="whitespace-nowrap">Owner</TH>
              <TH className="whitespace-nowrap">Updated</TH>
              <TH className="text-right">Action</TH>
            </TR>
          </THead>
          <tbody>
            {reports.length === 0 ? (
              <TR>
                <TD colSpan={5} className="py-10 text-center text-[var(--fg-secondary)]">
                  No reports found.
                </TD>
              </TR>
            ) : (
              reports.map((report) => (
                <TR key={report.id}>
                  <TD className="font-medium text-[var(--fg-primary)]">{report.title}</TD>
                  <TD>
                    <Badge tone={statusTone(report.status)}>
                      {report.status}
                    </Badge>
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">{report.owner_name ?? `${report.owner_user_id.slice(0, 8)}...`}</TD>
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
              ))
            )}
          </tbody>
        </Table>

        <Pagination page={page} totalPages={totalPages} onChange={goToPage} />
      </main>

    </div>
  );
}
