import { redirect } from "next/navigation";

import { getCurrentUserRole } from "@/lib/supabase/server";
import { listAnalystsAction } from "@/features/analyst-info/actions";
import { listSectorsGrouped } from "@/features/sectors/repo/sectors-repo";

import { ReviewReportPage as ReviewReportPageContent } from "@/features/report-review/components/review-report-page";

export default async function ReviewReportPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const role = await getCurrentUserRole();
  // analyst 也允许进入：仅用于查看 published/terminated 终态报告（只读视图）。
  // 组件层 isReadOnly 禁用所有输入；写操作（approve/reject/reopen/save）由
  // ensureReviewerRole 在 actions 层继续拦截 admin/sa。
  if (role !== "admin" && role !== "sa" && role !== "analyst") {
    redirect("/403");
  }

  // Fetch analysts list and sectors list on server side
  const [analystsResult, sectorsResult] = await Promise.all([
    listAnalystsAction({ page: 1, query: null }),
    listSectorsGrouped({ is_active: true }),
  ]);
  const analysts = analystsResult.ok ? analystsResult.data.items : [];
  const sectors = sectorsResult.ok ? sectorsResult.data : [];

  const { id } = await params;
  return (
    <ReviewReportPageContent
      reportId={id}
      userRole={role}
      analysts={analysts}
      sectors={sectors}
    />
  );
}
