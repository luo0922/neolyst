import { redirect } from "next/navigation";

import { isReportTerminal } from "@/domain/schemas/report";
import { getCurrentUser, getCurrentUserRole } from "@/lib/supabase/server";

import { EditReportPage as EditReportPageContent } from "@/features/reports/components/edit-report-page";
import { getReportDetailAction } from "@/features/reports/actions";

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

  // 终态（published/terminated）报告不可编辑：路由守卫层强制重定向回列表，
  // 避免任何角色（包括 admin）进入编辑页对终态报告进行误操作。
  const { id } = await params;
  const detailResult = await getReportDetailAction(id);
  if (detailResult.ok && isReportTerminal(detailResult.data.status)) {
    redirect("/reports");
  }

  return (
    <div className="max-w-4xl mx-auto">
      <EditReportPageContent params={params} userRole={role} currentUserId={user.id} />
    </div>
  );
}
