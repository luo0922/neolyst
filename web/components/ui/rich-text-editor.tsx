"use client";

import { Editor } from "@tinymce/tinymce-react";
import * as React from "react";
import { cn } from "@/lib/utils";

export interface RichTextEditorProps {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
  minHeight?: string;
}

export function RichTextEditor({
  label,
  value,
  onChange,
  placeholder = "",
  className = "",
  minHeight = "500px",
}: RichTextEditorProps) {
  return (
    <div className={cn("space-y-1.5", className)}>
      {label && (
        <label className="block text-sm font-medium text-zinc-300">
          {label}
        </label>
      )}
      <div
        className="rounded-[8px] border border-white/10 bg-zinc-900/70 overflow-hidden focus-within:ring-2 focus-within:ring-blue-500/60 focus-within:border-blue-500/60"
      >
        <Editor
          tinymceScriptSrc="/tinymce/tinymce.min.js"
          init={{
            base_url: "/tinymce",
            suffix: ".min",
            height: 500,
            min_height: 500,
            menubar: false,
            placeholder,
            font_formats:
              "楷体=KaiTi,'STKaiti','楷体','楷体GB_2312',Calibri,sans-serif;"
              + "宋体=SimSun,'宋体',serif;"
              + "黑体=SimHei,'黑体',sans-serif;"
              + "Times New Roman=Times New Roman,serif;"
              + "Consolas=Consolas,monospace;",
            content_style: `
              body {
                font-family: Calibri, '楷体GB2312', 'KaiTi', '楷体', 'STKaiti', sans-serif;
                text-align: justify;
                color: #000000;
                background: transparent;
                font-size: 16px;
                line-height: 1.6;
                padding: 8px 12px;
              }
              h1, h2, h3 { font-weight: bold; margin-top: 0.5em; margin-bottom: 0.25em; }
              h1 { font-size: 1.5em; }
              h2 { font-size: 1.25em; }
              h3 { font-size: 1.1em; }
              p { margin: 0 0 0.5em 0; }
              ul, ol { padding-left: 1.5em; margin: 0 0 0.5em 0; }
              strong, b { font-weight: bold; }
              em, i { font-style: italic; }
            `,
            toolbar:
              "formats | bold italic strikethrough | bullist numlist | removeformat",
            formats: {
              h1: { block: "h1", styles: { fontWeight: "bold" } },
              h2: { block: "h2", styles: { fontWeight: "bold" } },
              h3: { block: "h3", styles: { fontWeight: "bold" } },
            },
            browser_spellcheck: true,
            branding: false,
            resize: true,
            skin: "oxide-dark",
            content_css: "dark",
            setup: (editor) => {
              editor.on("init", () => {
                if (value) {
                  editor.setContent(value, { format: "html" });
                }
              });
            },
          }}
          initialValue={value}
          onEditorChange={onChange}
          id="investment-thesis-editor"
        />
      </div>
    </div>
  );
}
