import * as React from "react";

import { listAllActiveAnalysts } from "@/features/analyst-info/repo/analysts-repo";
import type { Analyst } from "@/features/analyst-info/repo/analysts-repo";
import { listAllUsersCapped } from "@/features/users/repo/users-admin-repo";

import { listReportsAction } from "../actions";
import { ReportsPageClient } from "./reports-page-client";

export interface ReportsPageProps {
  searchParams: Promise<{
    page?: string;
    query?: string;
    status?: string;
    report_type?: string;
    submitted_by?: string;
    analyst?: string;
  }>;
  userRole: "admin" | "sa" | "analyst";
  currentUserId: string;
}

const VALID_STATUSES = new Set<ReportStatus>([
  "draft",
  "submitted",
  "published",
  "rejected",
  "terminated",
]);

export async function ReportsPage({
  searchParams,
  userRole,
  currentUserId,
}: ReportsPageProps) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page ?? 1) || 1);
  const query = params.query?.trim() || null;
  const rawStatus = params.status?.trim() || "";
  const status: ReportStatus | null =
    rawStatus && rawStatus !== "all" && VALID_STATUSES.has(rawStatus as ReportStatus)
      ? (rawStatus as ReportStatus)
      : null;
  const report_type = params.report_type?.trim() || null;
  const submitted_by = params.submitted_by?.trim() || null;
  const analyst = params.analyst?.trim() || null;

  const [listResult, analystsResult, usersResult] = await Promise.all([
    listReportsAction({ page, query, status, report_type, submitted_by, analyst }),
    listAllActiveAnalysts(),
    listAllUsersCapped(),
  ]);

  if (!listResult.ok) {
    return (
      <div className="flex items-center justify-center p-8">
        <p className="text-[var(--fg-secondary)]">Failed to load reports: {listResult.error}</p>
      </div>
    );
  }

  const analysts = analystsResult.ok ? analystsResult.data : [];
  const users = usersResult.users;

  return (
    <ReportsPageClient
      reports={listResult.data.items}
      total={listResult.data.total}
      page={listResult.data.page}
      totalPages={listResult.data.totalPages}
      currentQuery={query}
      currentStatus={listResult.data.applied_status}
      currentReportType={report_type}
      currentSubmittedBy={submitted_by}
      currentAnalyst={analyst}
      analysts={analysts}
      users={users}
      userRole={userRole}
      currentUserId={currentUserId}
    />
  );
}
