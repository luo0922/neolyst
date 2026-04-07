/**
 * Templates feature public entry
 *
 * Exports client-safe functions, types, and components.
 * Server-only repo functions are NOT re-exported here.
 */

// Server Actions (client-safe)
export {
  listTemplatesGroupedAction,
  listTemplatesAction,
  getTemplateAction,
  createTemplateAction,
  updateTemplateAction,
  deleteTemplateAction,
} from "./actions";

// Types
export type { Template, TemplateGroup, ReportType } from "./repo/templates-repo";
