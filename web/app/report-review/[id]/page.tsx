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
  if (role !== "admin" && role !== "sa") {
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
