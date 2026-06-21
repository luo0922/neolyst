import * as React from "react";
import { notFound } from "next/navigation";

import { isReportTerminal } from "@/domain/schemas/report";
import { listAllActiveAnalysts } from "@/features/analyst-info/repo/analysts-repo";
import { listCoverages } from "@/features/coverage/repo/coverage-repo";
import { listAllRatings } from "@/features/ratings/repo/ratings-repo";
import { listSectorsGroupedAction } from "@/features/sectors/actions";
import { getReportDetailAction, listReportTypeOptionsAction } from "../actions";
import { EditReportPageClient } from "./edit-report-page-client";

export interface EditReportPageProps {
  params: Promise<{ id: string }>;
  userRole: "admin" | "analyst";
  currentUserId: string;
}

export async function EditReportPage({
  params,
  userRole,
  currentUserId,
}: EditReportPageProps) {
  const { id } = await params;

  const [detailResult, typesResult, analystsResult, sectorsResult, coveragesResult, ratingsResult] =
    await Promise.all([
      getReportDetailAction(id),
      listReportTypeOptionsAction(),
      listAllActiveAnalysts(),
      listSectorsGroupedAction({ is_active: true }),
      listCoverages({ page: 1, query: null }),
      listAllRatings(),
    ]);

  if (!detailResult.ok) {
    return (
      <div className="flex items-center justify-center p-8">
        <p className="text-[var(--fg-secondary)]">
          Failed to load report: {detailResult.error}
        </p>
      </div>
    );
  }

  const report = detailResult.data;

  // 终态（published/terminated）任何角色都不能编辑：理论上应已被路由守卫拦截，
  // 此处作为防御性兜底，触发 notFound 让用户回到列表。
  if (isReportTerminal(report.status)) {
    notFound();
  }

  // Check permission: admin can edit draft/submitted, analyst can only edit own draft/submitted
  const canEdit =
    userRole === "admin" ||
    (userRole === "analyst" &&
      report.owner_user_id === currentUserId &&
      (report.status === "draft" || report.status === "submitted"));

  if (!canEdit) {
    notFound();
  }

  if (!typesResult.ok) {
    return (
      <div className="flex items-center justify-center p-8">
        <p className="text-[var(--fg-secondary)]">
          Failed to load report type options: {typesResult.error}
        </p>
      </div>
    );
  }

  return (
    <EditReportPageClient
      report={report}
      userRole={userRole}
      currentUserId={currentUserId}
      reportTypes={typesResult.data}
      analysts={analystsResult.ok ? analystsResult.data : []}
      sectors={sectorsResult.ok ? sectorsResult.data : []}
      coverages={coveragesResult.ok ? coveragesResult.data.items : []}
      ratings={ratingsResult.ok ? ratingsResult.data : []}
    />
  );
}
