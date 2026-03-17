import { z } from "zod";

export const regionSchema = z.object({
  name_en: z.string().min(1, "English name is required").max(100, "Name too long"),
  name_cn: z.string().min(1, "Chinese name is required").max(100, "Name too long"),
  code: z.string().min(1, "Code is required").max(10, "Code too long"),
});

export const regionUpdateSchema = regionSchema.partial();
