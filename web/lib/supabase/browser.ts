/**
 * Browser Supabase Client
 *
 * 用于客户端组件，只能使用 anon key（RLS 兜底）
 *
 * @example
 * "use client";
 * import { createBrowserClient } from "@/lib/supabase/browser";
 *
 * const supabase = createBrowserClient();
 * const { data } = await supabase.from("users").select("*");
 */

import { createBrowserClient as createClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

export function createBrowserClient(): SupabaseClient {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

/**
 * 创建带有自定义 Storage URL 的 Supabase 客户端
 * 用于上传附件时使用公网地址
 */
export function createStorageClient(): SupabaseClient {
  const storageUrl = process.env.NEXT_PUBLIC_SUPABASE_STORAGE_URL;
  if (!storageUrl) {
    return createBrowserClient();
  }
  return createClient(
    storageUrl,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
