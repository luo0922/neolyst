-- Initialize template table with specified data.
-- Each report_type has both English (en) and Chinese (zh) versions.
-- file_type is 'docx' per business requirement.

-- 1. Delete all existing template data
DELETE FROM public.template;

-- 2. Insert new template data
INSERT INTO public.template (name, report_type, file_type, file_path, is_active, language, version, uploaded_by)
VALUES
  ('Company_Template_CN',   'company',        'report', '', true, 'zh', 1, NULL),
  ('Company_Template_EN',   'company',        'report', '', true, 'en', 1, NULL),
  ('Sector_Template_CN',    'sector',         'report', '', true, 'zh', 1, NULL),
  ('Sector_Template_EN',    'sector',         'report', '', true, 'en', 1, NULL),
  ('Company_Flash_Template_CN',  'company_flash',  'report', '', true, 'zh', 1, NULL),
  ('Company_Flash_Template_EN',  'company_flash',  'report', '', true, 'en', 1, NULL),
  ('Sector_Flash_Template_CN',   'sector_flash',   'report', '', true, 'zh', 1, NULL),
  ('Sector_Flash_Template_EN',   'sector_flash',   'report', '', true, 'en', 1, NULL),
  ('Macro_Template_CN',    'macro',          'report', '', true, 'zh', 1, NULL),
  ('Macro_Template_EN',    'macro',          'report', '', true, 'en', 1, NULL),
  ('Strategy_Template_CN', 'strategy',       'report', '', true, 'zh', 1, NULL),
  ('Strategy_Template_EN', 'strategy',       'report', '', true, 'en', 1, NULL),
  ('Quantitative_Template_CN', 'quantitative', 'report', '', true, 'zh', 1, NULL),
  ('Quantitative_Template_EN', 'quantitative', 'report', '', true, 'en', 1, NULL),
  ('Bond_Template_CN',     'bond',           'report', '', true, 'zh', 1, NULL),
  ('Bond_Template_EN',     'bond',           'report', '', true, 'en', 1, NULL);
