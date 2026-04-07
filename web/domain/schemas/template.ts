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

export const templateSchema = z.object({
  name: z.string().min(1, "Name is required").max(200, "Name too long"),
  report_type: z.enum(reportTypes),
});

export const templateUpdateSchema = z.object({
  name: z
    .string()
    .min(1, "Name is required")
    .max(200, "Name too long")
    .optional(),
});

export type TemplateInput = z.infer<typeof templateSchema>;
export type TemplateUpdateInput = z.infer<typeof templateUpdateSchema>;
export type ReportType = (typeof reportTypes)[number];
