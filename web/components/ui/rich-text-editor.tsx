"use client";

import * as React from "react";
import MDEditor from "@uiw/react-md-editor";
import { cn } from "@/lib/utils";
import "./markdown-editor.css";

export interface RichTextEditorProps {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
  minHeight?: string;
  readOnly?: boolean;
}

export function RichTextEditor({
  label,
  value,
  onChange,
  placeholder = "Enter markdown content...",
  className = "",
  minHeight = "500px",
  readOnly = false,
}: RichTextEditorProps) {
  const height = parseInt(minHeight, 10) || 500;

  return (
    <div className={cn("space-y-1.5", className)}>
      {label && (
        <label className="block text-sm font-medium text-zinc-300">
          {label}
        </label>
      )}
      <div
        data-color-mode="dark"
        style={{ "--editor-height": `${height}px` } as React.CSSProperties}
      >
        <MDEditor
          value={value}
          onChange={readOnly ? undefined : ((val) => onChange(val ?? ""))}
          preview={readOnly ? "preview" : "edit"}
          textareaProps={{
            placeholder,
          }}
        />
      </div>
    </div>
  );
}
