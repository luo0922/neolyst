import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";
import { createServerClient } from "@/lib/supabase/server";
import type { Result } from "@/lib/result";

interface AnalystInfo {
  full_name: string | null;
  chinese_name: string | null;
  email: string;
}

interface ReportPushData {
  reportId: string;
  triggeredBy: string;
  triggerType: "auto" | "manual";
}

export async function pushReportExternal(
  params: ReportPushData,
): Promise<Result<void>> {
  const adminClient = createAdminClient();
  const { reportId, triggeredBy, triggerType } = params;

  // 1. 前置校验
  const apiKey = process.env.EXTERNAL_REPORT_API_KEY;
  if (!apiKey) {
    await logPush({
      reportId,
      status: "failed",
      errorMessage: "EXTERNAL_REPORT_API_KEY not configured",
      payloadSent: null,
      triggeredBy,
      triggerType,
    });
    return { ok: true, data: undefined };
  }

  const externalApiUrl = process.env.EXTERNAL_API_URL;
  if (!externalApiUrl) {
    await logPush({
      reportId,
      status: "failed",
      errorMessage: "EXTERNAL_API_URL not configured",
      payloadSent: null,
      triggeredBy,
      triggerType,
    });
    return { ok: true, data: undefined };
  }

  // 2. 获取报告数据
  const { data: report, error: reportError } = await adminClient
    .from("report")
    .select(
      `
      id,
      title,
      report_type,
      published_at,
      ticker,
      rating,
      target_price,
      region_code,
      report_language,
      investment_thesis,
      contact_person_id,
      sector_id,
      current_version_no,
      coverage_id
    `,
    )
    .eq("id", reportId)
    .single();

  if (reportError || !report) {
    const msg = reportError?.message ?? "Report not found";
    await logPush({
      reportId,
      status: "failed",
      errorMessage: msg,
      payloadSent: null,
      triggeredBy,
      triggerType,
    });
    return { ok: true, data: undefined };
  }

  // 3. 必填字段校验
  if (!report.title || !report.report_type || !report.published_at) {
    await logPush({
      reportId,
      status: "failed",
      errorMessage:
        "Missing required fields: title, report_type, or published_at",
      payloadSent: {
        has_title: !!report.title,
        has_report_type: !!report.report_type,
        has_published_at: !!report.published_at,
      },
      triggeredBy,
      triggerType,
    });
    return { ok: true, data: undefined };
  }

  // 4. 获取最新版本的 PDF 文件路径
  const { data: reportVersion } = await adminClient
    .from("report_version")
    .select("pdf_file_path, pdf_file_name")
    .eq("report_id", reportId)
    .eq("version_no", report.current_version_no)
    .single();

  const pdfFilePath = reportVersion?.pdf_file_path ?? null;
  const pdfFileName = reportVersion?.pdf_file_name ?? null;

  // 5. 获取分析师信息
  const { data: reportAnalysts } = await adminClient
    .from("report_analyst")
    .select("analyst_id, sort_order")
    .eq("report_id", reportId)
    .order("sort_order", { ascending: true });

  let analystField = "";
  if (reportAnalysts && reportAnalysts.length > 0) {
    const analystIds = reportAnalysts.map((ra) => ra.analyst_id);
    const { data: analysts } = await adminClient
      .from("analyst")
      .select("full_name, chinese_name, email")
      .in("id", analystIds);

    if (analysts) {
      analystField = analysts
        .map((a) => {
          const name = a.full_name ?? a.chinese_name ?? "";
          return name ? `${name}<${a.email}>` : `<${a.email}>`;
        })
        .join(",");
    }
  }

  // 6. 获取地区名称
  let regionName: string | null = null;
  if (report.region_code) {
    const { data: region } = await adminClient
      .from("region")
      .select("name_en")
      .eq("code", report.region_code)
      .single();
    regionName = region?.name_en ?? null;
  }

  // 7. 获取行业分类名称
  let sectorName: string | null = null;
  if (report.sector_id) {
    const { data: sector } = await adminClient
      .from("sector")
      .select("name_cn")
      .eq("id", report.sector_id)
      .single();
    sectorName = sector?.name_cn ?? null;
  }

  // 8. 获取 coverage 的 english_full_name 作为 ticker_name
  let tickerName: string | null = null;
  if (report.coverage_id) {
    const { data: coverage } = await adminClient
      .from("coverage")
      .select("english_full_name")
      .eq("id", report.coverage_id)
      .single();
    tickerName = coverage?.english_full_name ?? null;
  }

  // 9. 获取联系人信息
  let contactPersonField: string | null = null;
  if (report.contact_person_id) {
    const { data: contactUser } = await adminClient
      .from("auth.users")
      .select("raw_user_meta_data")
      .eq("id", report.contact_person_id)
      .single();

    if (contactUser?.raw_user_meta_data) {
      const meta = contactUser.raw_user_meta_data as Record<string, string>;
      const name = meta.full_name ?? meta.name ?? "";
      const email = meta.email ?? "";
      if (name && email) {
        contactPersonField = `${name}<${email}>`;
      }
    }
  }

  // 10. 下载 PDF 文件
  let pdfBlob: Blob | null = null;
  if (pdfFilePath) {
    const { data: pdfData, error: pdfError } = await adminClient.storage
      .from("reports")
      .download(pdfFilePath);

    if (pdfError || !pdfData) {
      console.warn(
        `Failed to download PDF for report ${reportId}:`,
        pdfError?.message,
      );
    } else {
      pdfBlob = pdfData;
    }
  }

  // 11. 构造 FormData
  const formData = new FormData();

  // 必填字段
  formData.append("external_id", report.id);
  formData.append("title", report.title);
  formData.append("report_type", report.report_type);
  formData.append(
    "published_at",
    new Date(report.published_at).toISOString(),
  );

  // 可选字段
  if (report.ticker) formData.append("ticker", report.ticker);
  if (report.rating) formData.append("rating", report.rating);
  if (report.target_price && Number(report.target_price) > 0) {
    formData.append("target_price", report.target_price);
  }
  if (regionName) formData.append("region", regionName);
  if (sectorName) formData.append("sector", sectorName);
  if (
    report.report_language &&
    (report.report_language === "zh" || report.report_language === "en")
  ) {
    formData.append("report_language", report.report_language);
  }
  if (report.investment_thesis) {
    formData.append("investment_thesis", report.investment_thesis);
  }
  if (analystField) formData.append("analyst", analystField);
  if (tickerName) formData.append("ticker_name", tickerName);
  if (contactPersonField) {
    formData.append("contact_person", contactPersonField);
  }

  // PDF 附件
  if (pdfBlob && pdfFileName) {
    formData.append("attachment_pdf", pdfBlob, pdfFileName);
  }

  // 12. 调用外部接口
  let httpStatusCode: number | null = null;
  let responseBody = "";
  let errorMessage: string | null = null;
  let pushStatus: "success" | "failed" = "failed";

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30_000);

    const response = await fetch(`${externalApiUrl}/api/external/reports`, {
      method: "POST",
      headers: {
        "X-API-Key": apiKey,
      },
      body: formData,
      signal: controller.signal,
    });

    clearTimeout(timeout);

    httpStatusCode = response.status;
    responseBody = (await response.text()).slice(0, 2000);
    pushStatus = response.ok ? "success" : "failed";
    if (!response.ok) {
      errorMessage = `HTTP ${response.status}`;
    }
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") {
      errorMessage = "timeout";
    } else {
      errorMessage = err instanceof Error ? err.message : "Unknown error";
    }
  }

  // 13. 记录推送日志
  await logPush({
    reportId,
    status: pushStatus,
    httpStatusCode,
    responseBody,
    errorMessage,
    payloadSent: {
      external_id: report.id,
      title: report.title,
      report_type: report.report_type,
      published_at: report.published_at,
      has_ticker: !!report.ticker,
      has_rating: !!report.rating,
      has_target_price: !!report.target_price,
      has_region: !!regionName,
      has_sector: !!sectorName,
      has_report_language: !!report.report_language,
      has_investment_thesis: !!report.investment_thesis,
      has_analyst: !!analystField,
      has_ticker_name: !!tickerName,
      has_contact_person: !!contactPersonField,
      attachment_pdf: pdfFileName ?? null,
      attachment_size: pdfBlob?.size ?? null,
    },
    triggeredBy,
    triggerType,
  });

  return { ok: true, data: undefined };
}

async function logPush(params: {
  reportId: string;
  status: "success" | "failed" | "pending";
  httpStatusCode?: number | null;
  responseBody?: string;
  errorMessage?: string | null;
  payloadSent: Record<string, unknown> | null;
  triggeredBy: string;
  triggerType: "auto" | "manual";
}): Promise<void> {
  try {
    const adminClient = createAdminClient();
    await adminClient.from("report_push_log").insert({
      report_id: params.reportId,
      status: params.status,
      http_status_code: params.httpStatusCode ?? null,
      response_body: params.responseBody ?? null,
      error_message: params.errorMessage ?? null,
      payload_sent: params.payloadSent ?? null,
      trigger_type: params.triggerType,
      triggered_by: params.triggeredBy,
    });
  } catch (err) {
    console.error("Failed to write push log:", err);
  }
}
