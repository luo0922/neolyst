"use client";

import * as React from "react";

import { cn } from "@/lib/cn";

export type FileDropzoneProps = {
  label: string;
  accept?: string;
  file: File | null;
  disabled?: boolean;
  error?: string;
  hint?: string;
  onFileChange: (file: File | null) => void;
};

export function FileDropzone({
  label,
  accept,
  file,
  disabled = false,
  error,
  hint,
  onFileChange,
}: FileDropzoneProps) {
  const inputId = React.useId();
  const [isDragging, setIsDragging] = React.useState(false);

  function handleFiles(fileList: FileList | null) {
    if (!fileList || fileList.length === 0 || disabled) {
      return;
    }
    onFileChange(fileList[0]);
  }

  return (
    <div className="space-y-1.5">
      <label htmlFor={inputId} className="block text-sm font-medium text-[var(--fg-secondary)]">
        {label}
      </label>
      <label
        htmlFor={inputId}
        className={cn(
          "block rounded-[8px] border border-dashed border-[var(--border-default)] bg-[var(--bg-surface)]/60 p-4",
          "transition-all duration-200",
          !disabled && "cursor-pointer hover:border-[var(--accent)] hover:bg-[var(--bg-surface)]",
          isDragging && "border-[var(--accent)] bg-[var(--accent-soft)]",
          disabled && "cursor-not-allowed opacity-60",
          error && "border-[var(--error)]",
        )}
        onDragOver={(event) => {
          if (disabled) return;
          event.preventDefault();
          setIsDragging(true);
        }}
        onDragLeave={(event) => {
          event.preventDefault();
          setIsDragging(false);
        }}
        onDrop={(event) => {
          if (disabled) return;
          event.preventDefault();
          setIsDragging(false);
          handleFiles(event.dataTransfer.files);
        }}
      >
        <span className="sr-only">
          <input
            id={inputId}
            type="file"
            accept={accept}
            disabled={disabled}
            onChange={(event) => handleFiles(event.target.files)}
          />
        </span>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="min-w-0">
            <p className="text-sm text-[var(--fg-primary)]">
              {file ? file.name : "Drag file here or click to choose"}
            </p>
            {hint ? <p className="text-xs text-[var(--fg-tertiary)]">{hint}</p> : null}
          </div>
          <span
            className={cn(
              "inline-flex items-center justify-center gap-2 rounded-[6px] border border-[var(--border-default)] bg-[var(--bg-surface)] px-4 py-2 text-sm font-medium text-[var(--fg-primary)]",
              "transition-all duration-200 hover:bg-[var(--bg-surface-hover)]",
              disabled && "cursor-not-allowed opacity-60",
            )}
            onClick={(e) => e.stopPropagation()}
          >
            Choose File
          </span>
        </div>
      </label>
      {error ? <p className="text-xs text-[var(--error)]">{error}</p> : null}
    </div>
  );
}
