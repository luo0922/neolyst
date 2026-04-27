import "server-only";

import { err, ok, type Result } from "@/lib/result";
import { createServerClient } from "@/lib/supabase/server";

// New schema: only name, code, rank. No id / is_active / created_at.
export type Rating = {
  name: string;
  code: string;
  rank: number;
};

/**
 * List all ratings, sorted by rank field
 */
export async function listAllRatings(): Promise<Result<Rating[]>> {
  const supabase = await createServerClient();

  const { data, error } = await supabase
    .from("rating")
    .select("name, code, rank")
    .order("rank", { ascending: true });

  if (error) return err(error.message);
  if (!data) return err("Failed to fetch ratings");

  return ok(data);
}
