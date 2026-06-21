"use server";

import { revalidatePath } from "next/cache";

import {
  reportReviewActionSchema,
  reportSaveSchema,
  reportSubmitSchema,
  isReportTerminal,
  type ReportStatus,
} from "@/domain/schemas/report";
import { err, type Result } from "@/lib/result";
import { requireAuth } from "@/lib/supabase/server";

import {
  approveReport,
  getReviewReportDetail,
  listReviewReports,
  rejectReportAction,
  reopenReportAction,
  saveReviewReportContent,
} from "./repo/report-review-repo";
import {
  listReportPushHistory,
  repushReport,
} from "./repo/report-push-repo";

type ReviewFilterStatus = "all" | "submitted" | "published" | "rejected" | "terminated";
type Role = "admin" | "sa" | "analyst";

async function getReviewerActor(): Promise<
  Result<{ user: Awaited<ReturnType<typeof requireAuth>>; role: Role }>
> {
  try {
    const user = await requireAuth();
    const role = user.app_metadata?.role as Role | undefined;
    if (role !== "admin" && role !== "sa" && role !== "analyst") {
      return err("No permission");
    }
    return { ok: true, data: { user, role } };
  } catch {
    return err("Unauthorized");
  }
}

function ensureReviewerRole(role: Role): Result<null> {
  if (role !== "admin" && role !== "sa") {
    return err("No permission");
  }
  return { ok: true, data: null };
}

export async function listReviewReportsAction(input: {
  page?: number;
  query?: string | null;
  status?: ReviewFilterStatus | null;
  report_type?: string | null;
  contact_person?: string | null;
  analyst?: string | null;
}): Promise<
  Result<{
    items: Awaited<ReturnType<typeof listReviewReports>> extends Result<infer T>
      ? T extends { items: infer U }
        ? U
        : never
      : never;
    total: number;
    page: number;
    totalPages: number;
    applied_status: ReviewFilterStatus;
  }>
> {
  const actor = await getReviewerActor();
  if (!actor.ok) {
    return actor;
  }

  const roleCheck = ensureReviewerRole(actor.data.role);
  if (!roleCheck.ok) {
    return roleCheck;
  }

  const page = Math.max(1, input.page ?? 1);
  const query = input.query ?? null;
  const status = input.status ?? "all";

  const result = await listReviewReports({
    page,
    query,
    status,
    report_type: input.report_type ?? null,
    contact_person: input.contact_person ?? null,
    analyst: input.analyst ?? null,
  });
  if (!result.ok) {
    return result;
  }

  return {
    ok: true,
    data: {
      ...result.data,
      applied_status: status,
    },
  };
}

export async function getReviewReportDetailAction(
  reportId: string,
): Promise<Result<Awaited<ReturnType<typeof getReviewReportDetail>> extends Result<infer T> ? T : never>> {
  const actor = await getReviewerActor();
  if (!actor.ok) {
    return actor;
  }

  // 仅 admin/sa 可继续；analyst 仅用于查看 published/terminated 终态报告，
  // 组件层 isReadOnly 已禁用所有输入控件，且 executeReviewAction/saveReviewReportAction
  // 仍由 ensureReviewerRole 拦截，analyst 无法触发任何写操作。
  if (actor.data.role !== "admin" && actor.data.role !== "sa" && actor.data.role !== "analyst") {
    return err("No permission");
  }

  return getReviewReportDetail(reportId);
}

function validateStatusTransition(
  currentStatus: ReportStatus,
  action: "approve" | "reject" | "reopen",
): Result<null> {
  if (action === "approve" || action === "reject") {
    if (currentStatus !== "submitted") {
      return err("Only submitted reports can be approved or rejected.");
    }
    return { ok: true, data: null };
  }

  if (action === "reopen" && currentStatus !== "rejected") {
    return err("Only rejected reports can be reopened.");
  }

  return { ok: true, data: null };
}

export async function executeReviewAction(input: unknown): Promise<Result<Awaited<ReturnType<typeof getReviewReportDetail>> extends Result<infer T> ? T : never>> {
  const actor = await getReviewerActor();
  if (!actor.ok) {
    return actor;
  }

  const roleCheck = ensureReviewerRole(actor.data.role);
  if (!roleCheck.ok) {
    return roleCheck;
  }

  const parsed = reportReviewActionSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  const detailResult = await getReviewReportDetail(parsed.data.report_id);
  if (!detailResult.ok) {
    return detailResult;
  }

  const statusCheck = validateStatusTransition(
    detailResult.data.status,
    parsed.data.action,
  );
  if (!statusCheck.ok) {
    return statusCheck;
  }

  const actionBy = actor.data.user.id;
  const actionResult =
    parsed.data.action === "approve"
      ? await approveReport({ report_id: parsed.data.report_id, action_by: actionBy })
      : parsed.data.action === "reject"
        ? await rejectReportAction({
            report_id: parsed.data.report_id,
            action_by: actionBy,
            reason: parsed.data.reason,
          })
        : await reopenReportAction({ report_id: parsed.data.report_id, action_by: actionBy });

  if (actionResult.ok) {
    revalidatePath("/report-review");
    revalidatePath("/reports");
  }

  return actionResult;
}

export async function getReviewReportAction(input: unknown): Promise<Result<Awaited<ReturnType<typeof getReviewReportDetail>> extends Result<infer T> ? T : never>> {
  const parsed = reportSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  return getReviewReportDetailAction(parsed.data.report_id);
}

export async function saveReviewReportAction(input: unknown): Promise<Result<Awaited<ReturnType<typeof getReviewReportDetail>> extends Result<infer T> ? T : never>> {
  const actor = await getReviewerActor();
  if (!actor.ok) {
    return actor;
  }

  const roleCheck = ensureReviewerRole(actor.data.role);
  if (!roleCheck.ok) {
    return roleCheck;
  }

  const parsed = reportSaveSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.issues[0]?.message ?? "Invalid input.");
  }

  // 终态拦截：published/terminated 报告不允许任何修改（审批人也不行）。
  const detailResult = await getReviewReportDetail(parsed.data.report_id);
  if (!detailResult.ok) {
    return detailResult;
  }
  if (isReportTerminal(detailResult.data.status)) {
    return err("Published or terminated reports cannot be modified.");
  }
  // 审批人编辑仅允许处于 submitted 状态的报告（与 repo 内 .eq("status","submitted") 对齐）。
  if (detailResult.data.status !== "submitted") {
    return err("Only submitted reports can be edited from the review page.");
  }

  const result = await saveReviewReportContent({
    ...parsed.data,
    changed_by: actor.data.user.id,
  });

  if (result.ok) {
    revalidatePath("/report-review");
    revalidatePath("/reports");
  }

  return result;
}

export async function listReportPushHistoryAction(reportId: string) {
  return listReportPushHistory(reportId);
}

export async function repushReportAction(reportId: string) {
  const actor = await getReviewerActor();
  if (!actor.ok) {
    return actor;
  }

  const roleCheck = ensureReviewerRole(actor.data.role);
  if (!roleCheck.ok) {
    return roleCheck;
  }

  return repushReport(reportId);
}
