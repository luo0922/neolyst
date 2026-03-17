import * as React from "react";

import { listSectorsGroupedAction } from "../actions";
import { SectorsPageClient } from "./sectors-page-client";

export interface SectorsPageProps {
  searchParams: Promise<{
    query?: string;
  }>;
}

export async function SectorsPage({ searchParams }: SectorsPageProps) {
  const params = await searchParams;
  const query = params.query ?? null;

  const result = await listSectorsGroupedAction({ query: query ?? undefined });

  if (!result.ok) {
    return (
      <div className="flex items-center justify-center p-8">
        <p className="text-[var(--fg-secondary)]">Failed to load sectors: {result.error}</p>
      </div>
    );
  }

  const sectors = result.data;

  return (
    <SectorsPageClient
      sectors={sectors}
      currentQuery={query}
    />
  );
}
