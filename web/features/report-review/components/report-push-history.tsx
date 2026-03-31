"use client";

import * as React from "react";

import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/toast";
import { listReportPushHistoryAction, repushReportAction } from "../actions";

interface ReportPushHistoryProps {
  reportId: string;
  isAdmin: boolean;
  reportStatus: string;
}

export function ReportPushHistory({
  reportId,
  isAdmin,
  reportStatus,
}: ReportPushHistoryProps) {
  const toast = useToast();
  const [history, setHistory] = React.useState<
    Array<{
      id: string;
      status: "success" | "failed" | "pending";
      httpStatusCode: number | null;
      errorMessage: string | null;
      triggerType: "auto" | "manual";
      createdAt: string;
      triggeredByName: string;
    }>
  >([]);
  const [loading, setLoading] = React.useState(true);
  const [repushLoading, setRepushLoading] = React.useState(false);

  React.useEffect(() => {
    listReportPushHistoryAction(reportId).then((result) => {
      setLoading(false);
      if (result.ok) {
        setHistory(result.data);
      }
    });
  }, [reportId]);

  async function handleRepush() {
    setRepushLoading(true);
    const result = await repushReportAction(reportId);
    setRepushLoading(false);
    if (result.ok) {
      toast.success("重新推送已触发");
      // Refresh history
      const refreshResult = await listReportPushHistoryAction(reportId);
      if (refreshResult.ok) {
        setHistory(refreshResult.data);
      }
    } else {
      toast.error(result.error ?? "重新推送失败");
    }
  }

  if (loading) {
    return (
      <div className="text-sm text-[var(--fg-secondary)]">加载推送历史...</div>
    );
  }

  if (history.length === 0 && reportStatus !== "published") {
    return null;
  }

  return (
    <div className="mt-6">
      <div className="flex items-center justify-between">
        <h3 className="text-base font-semibold">外部推送历史</h3>
        {isAdmin && reportStatus === "published" && (
          <Button
            variant="secondary"
            isLoading={repushLoading}
            onClick={handleRepush}
          >
            重新推送
          </Button>
        )}
      </div>

      {history.length === 0 ? (
        <p className="mt-2 text-sm text-[var(--fg-secondary)]">
          暂无推送记录
        </p>
      ) : (
        <div className="mt-3 space-y-2">
          {history.map((item) => (
            <div
              key={item.id}
              className="flex items-start gap-3 rounded-lg border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-3 text-sm"
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-[var(--fg-secondary)]">
                    {new Date(item.createdAt).toLocaleString("zh-CN")}
                  </span>
                  <span
                    className={`rounded px-1.5 py-0.5 text-xs font-medium ${
                      item.triggerType === "auto"
                        ? "bg-[var(--bg-tertiary)] text-[var(--fg-secondary)]"
                        : "bg-blue-100 text-blue-700"
                    }`}
                  >
                    {item.triggerType === "auto" ? "自动" : "手动"}
                  </span>
                  <span className="text-[var(--fg-secondary)]">
                    {item.triggeredByName}
                  </span>
                  {item.httpStatusCode && (
                    <span
                      className={`text-xs ${
                        item.status === "success"
                          ? "text-green-600"
                          : "text-red-600"
                      }`}
                    >
                      HTTP {item.httpStatusCode}
                    </span>
                  )}
                </div>
                {item.errorMessage && (
                  <p className="mt-1 text-xs text-red-500">
                    {item.errorMessage}
                  </p>
                )}
              </div>
              <PushStatusInline status={item.status} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function PushStatusInline({
  status,
}: {
  status: "success" | "failed" | "pending";
}) {
  const config = {
    success: { label: "成功", className: "text-green-600" },
    failed: { label: "失败", className: "text-red-500" },
    pending: { label: "推送中", className: "text-gray-400" },
  };
  const { label, className } = config[status];
  return (
    <span className={`text-sm font-medium ${className}`}>{label}</span>
  );
}
