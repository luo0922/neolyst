"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

import { ActionButton } from "@/components/ui/action-button";
import { Button } from "@/components/ui/button";
import { ConfirmModal } from "@/components/ui/confirm-modal";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Pagination } from "@/components/ui/pagination";
import { Table, TD, TH, THead, TR } from "@/components/ui/table";
import { useToast } from "@/components/ui/toast";
import { formatShanghaiYmd } from "@/lib/time";
import {
  createRegionAction,
  deleteRegionAction,
  updateRegionAction,
} from "../actions";
import type { Region } from "../repo/regions-repo";

export interface RegionsPageClientProps {
  regions: Region[];
  total: number;
  page: number;
  totalPages: number;
  currentQuery: string | null;
}

function toQueryString(params: { q: string; page: number }) {
  const q = params.q.trim();
  const sp = new URLSearchParams();
  if (q) sp.set("query", q);
  if (params.page > 1) sp.set("page", String(params.page));
  const s = sp.toString();
  return s ? `?${s}` : "";
}

export function RegionsPageClient({
  regions,
  total,
  page,
  totalPages,
  currentQuery,
}: RegionsPageClientProps) {
  const router = useRouter();
  const toast = useToast();

  const [queryDraft, setQueryDraft] = React.useState(currentQuery ?? "");
  React.useEffect(() => setQueryDraft(currentQuery ?? ""), [currentQuery]);

  // Create/Edit modal
  const [formOpen, setFormOpen] = React.useState(false);
  const [editingRegion, setEditingRegion] = React.useState<Region | null>(null);
  const [formNameEn, setFormNameEn] = React.useState("");
  const [formNameCn, setFormNameCn] = React.useState("");
  const [formCode, setFormCode] = React.useState("");
  const [formErrors, setFormErrors] = React.useState<{
    name_en?: string;
    name_cn?: string;
    code?: string;
  }>({});
  const [formLoading, setFormLoading] = React.useState(false);

  // Delete confirm
  const [deleteOpen, setDeleteOpen] = React.useState(false);
  const [deleteId, setDeleteId] = React.useState<string | null>(null);
  const [deleteLoading, setDeleteLoading] = React.useState(false);

  function openCreate() {
    setEditingRegion(null);
    setFormNameEn("");
    setFormNameCn("");
    setFormCode("");
    setFormErrors({});
    setFormOpen(true);
  }

  function openEdit(region: Region) {
    setEditingRegion(region);
    setFormNameEn(region.name_en);
    setFormNameCn(region.name_cn);
    setFormCode(region.code);
    setFormErrors({});
    setFormOpen(true);
  }

  async function submitForm(e: React.FormEvent) {
    e.preventDefault();

    const name_en = formNameEn.trim();
    const name_cn = formNameCn.trim();
    const code = formCode.trim();

    const next: { name_en?: string; name_cn?: string; code?: string } = {};
    if (!name_en) next.name_en = "English name is required";
    if (!name_cn) next.name_cn = "Chinese name is required";
    if (!code) next.code = "Code is required";
    setFormErrors(next);
    if (Object.keys(next).length) return;

    setFormLoading(true);
    const res = editingRegion
      ? await updateRegionAction(editingRegion.id, { name_en, name_cn, code })
      : await createRegionAction({ name_en, name_cn, code });
    setFormLoading(false);

    if (!res.ok) {
      toast.error(res.error, { title: "Error" });
      return;
    }

    setFormOpen(false);
    toast.success(editingRegion ? "Region updated." : "Region created.", {
      title: "Success",
    });
    router.refresh();
  }

  function openDelete(region: Region) {
    setDeleteId(region.id);
    setDeleteOpen(true);
  }

  async function confirmDelete() {
    if (!deleteId) return;

    setDeleteLoading(true);
    const res = await deleteRegionAction(deleteId);
    setDeleteLoading(false);

    if (!res.ok) {
      toast.error(res.error, { title: "Error" });
      return;
    }

    setDeleteOpen(false);
    toast.success("Region deleted.", { title: "Success" });
    router.refresh();
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    router.push(`/regions${toQueryString({ q: queryDraft, page: 1 })}`);
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]/60 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div className="text-xl font-semibold text-[var(--fg-primary)]">Regions</div>
          <Button onClick={openCreate}>Create Region</Button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-4 px-6 py-8">
        <div className="flex items-end justify-between gap-4">
          <form className="w-full max-w-md" onSubmit={submitSearch}>
            <Input
              label="Search"
              placeholder="Search by name or code"
              value={queryDraft}
              onChange={(e) => setQueryDraft(e.target.value)}
            />
          </form>
          <div className="hidden text-sm text-[var(--fg-secondary)] sm:block">
            {total} regions
          </div>
        </div>

        <Table>
          <THead>
            <TR className="hover:bg-transparent">
              <TH>Name (EN)</TH>
              <TH>Name (CN)</TH>
              <TH>Code</TH>
              <TH>Created</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <tbody>
            {regions.length === 0 ? (
              <TR className="hover:bg-transparent">
                <TD colSpan={5} className="py-10 text-center text-[var(--fg-secondary)]">
                  No regions found
                </TD>
              </TR>
            ) : (
              regions.map((region) => (
                <TR key={region.id}>
                  <TD className="font-medium text-[var(--fg-primary)]">{region.name_en}</TD>
                  <TD className="text-[var(--fg-secondary)]">{region.name_cn}</TD>
                  <TD>
                    <code className="rounded bg-[var(--bg-surface-hover)] px-1.5 py-0.5 text-xs text-[var(--fg-secondary)]">
                      {region.code}
                    </code>
                  </TD>
                  <TD className="text-[var(--fg-secondary)]">
                    {formatShanghaiYmd(region.created_at)}
                  </TD>
                  <TD>
                    <div className="flex justify-end gap-2">
                      <ActionButton onClick={() => openEdit(region)}>
                        Edit
                      </ActionButton>
                      <ActionButton
                        tone="danger"
                        onClick={() => openDelete(region)}
                      >
                        Delete
                      </ActionButton>
                    </div>
                  </TD>
                </TR>
              ))
            )}
          </tbody>
        </Table>

        <Pagination
          page={page}
          totalPages={totalPages}
          onChange={(p) =>
            router.push(`/regions${toQueryString({ q: queryDraft, page: p })}`)
          }
        />
      </main>

      <Modal
        open={formOpen}
        title={editingRegion ? "Edit region" : "Create region"}
        onClose={() => setFormOpen(false)}
        footer={
          <>
            <Button
              variant="ghost"
              type="button"
              onClick={() => setFormOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" form="region-form" isLoading={formLoading}>
              {editingRegion ? "Save" : "Create"}
            </Button>
          </>
        }
      >
        <form id="region-form" className="space-y-3" onSubmit={submitForm}>
          <Input
            id="name_en"
            label="Name (English)"
            placeholder="e.g., China"
            value={formNameEn}
            onChange={(e) => setFormNameEn(e.target.value)}
            error={formErrors.name_en}
          />
          <Input
            id="name_cn"
            label="Name (Chinese)"
            placeholder="e.g., 中国"
            value={formNameCn}
            onChange={(e) => setFormNameCn(e.target.value)}
            error={formErrors.name_cn}
          />
          <Input
            id="code"
            label="Code"
            placeholder="e.g., CN"
            value={formCode}
            onChange={(e) => setFormCode(e.target.value)}
            error={formErrors.code}
          />
        </form>
      </Modal>

      <ConfirmModal
        open={deleteOpen}
        title="Delete region?"
        description="This action cannot be undone."
        onClose={() => setDeleteOpen(false)}
        onConfirm={confirmDelete}
        confirmTone="danger"
        confirmLabel="Delete"
        loading={deleteLoading}
      />
    </div>
  );
}
