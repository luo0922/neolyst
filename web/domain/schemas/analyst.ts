import { z } from "zod";

export const analystEmailSchema = z.string().email("Invalid email address");

export const analystSchema = z.object({
  english_name: z.string().min(1, "English name is required").max(200, "English name too long"),
  chinese_name: z.string().max(100, "Chinese name too long").optional(),
  email: analystEmailSchema,
  region_code: z.string().max(10, "Region code is required"),
  suffix: z.string().max(50, "Suffix too long").optional(),
  sfc: z.string().max(50, "SFC too long").optional(),
  is_active: z.boolean().optional(),
});

export const analystUpdateSchema = analystSchema.partial();

// Create schema with required fields
export const analystCreateSchema = analystSchema.pick({
  english_name: true,
  chinese_name: true,
  email: true,
  region_code: true,
  suffix: true,
  sfc: true,
});
