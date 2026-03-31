"use client";

import * as React from "react";

import { Badge } from "@/components/ui/badge";

interface PushStatusBadgeProps {
  status: "success" | "failed" | "pending";
}

export function PushStatusBadge({ status }: PushStatusBadgeProps) {
  const config: Record<
    string,
    { label: string; tone: "green" | "red" | "secondary" | "blue" }
  > = {
    success: { label: "成功", tone: "green" },
    failed: { label: "失败", tone: "red" },
    pending: { label: "推送中", tone: "secondary" },
  };
  const { label, tone } = config[status] ?? { label: status, tone: "gray" };
  return <Badge tone={tone}>{label}</Badge>;
}
