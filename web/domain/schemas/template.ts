import { z } from "zod";

export const reportTypes = [
  "company",
  "sector",
  "company_flash",
  "sector_flash",
  "macro",
  "strategy",
  "quantitative",
  "bond",
] as const;

// Template schema: id is auto-generated as ${report_type}_${language} on the server side
export const templateSchema = z.object({
  report_type: z.enum(reportTypes),
  language: z.enum(["en", "zh"]),
});

export const templateUpdateSchema = z.object({});

export type TemplateInput = z.infer<typeof templateSchema>;
export type TemplateUpdateInput = z.infer<typeof templateUpdateSchema>;
export type ReportType = (typeof reportTypes)[number];
