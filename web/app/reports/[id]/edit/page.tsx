import { redirect } from "next/navigation";

import { getCurrentUser, getCurrentUserRole } from "@/lib/supabase/server";

import { EditReportPage as EditReportPageContent } from "@/features/reports/components/edit-report-page";

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

  return (
    <div className="max-w-4xl mx-auto">
      <EditReportPageContent params={params} userRole={role} currentUserId={user.id} />
    </div>
  );
}
