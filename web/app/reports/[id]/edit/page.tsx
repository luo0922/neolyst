import { redirect } from "next/navigation";

import { getCurrentUser, getCurrentUserRole } from "@/lib/supabase/server";

import { EditReportPage as EditReportPageContent } from "@/features/reports/components/edit-report-page";
import { getReportDetailAction } from "@/features/reports/actions";
import { ReportPushHistory } from "@/features/report-review/components/report-push-history";

export default async function EditReportPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  const role = await getCurrentUserRole();
  if (role !== "admin" && role !== "analyst") {
    redirect("/403");
  }

  const { id } = await params;
  const detailResult = await getReportDetailAction(id);

  return (
    <div className="max-w-4xl mx-auto">
      <EditReportPageContent params={params} userRole={role} currentUserId={user.id} />
      {detailResult.ok && (
        <div className="mt-8">
          <ReportPushHistory
            reportId={id}
            isAdmin={role === "admin"}
            reportStatus={detailResult.data.status}
          />
        </div>
      )}
    </div>
  );
}
