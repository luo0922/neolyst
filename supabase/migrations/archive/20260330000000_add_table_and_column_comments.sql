-- ============================================================
-- Add table and column comments for all database objects
-- Purpose: Improve database documentation for developers and tools
-- Idempotent: safe to run multiple times
-- ============================================================

-- ============================================================
-- region 表
-- ============================================================
comment on table public.region is '区域表：存储研究覆盖的地理区域信息，支持中英文名称和ISO 3166-1 alpha-2编码';
comment on column public.region.id is '主键UUID';
comment on column public.region.name_en is '区域英文名称';
comment on column public.region.name_cn is '区域中文名称';
comment on column public.region.code is 'ISO 3166-1 alpha-2 国家/地区代码（如CN、HK、JP等）';
comment on column public.region.is_active is '是否启用：true=启用，false=禁用';
comment on column public.region.created_at is '创建时间（UTC）';
comment on column public.region.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- analyst 表
-- ============================================================
comment on table public.analyst is '分析师信息表：存储分析师的详细资料，与auth.users解耦';
comment on column public.analyst.id is '主键UUID';
comment on column public.analyst.full_name is '分析师英文全名';
comment on column public.analyst.chinese_name is '分析师中文名';
comment on column public.analyst.email is '分析师邮箱（唯一，citext类型不区分大小写）';
comment on column public.analyst.region_code is '所属区域代码（ISO 3166-1 alpha-2），关联region.code，删除区域时置空';
comment on column public.analyst.suffix is '分析师姓名后缀（如Jr.、Sr.等）';
comment on column public.analyst.sfc is '分析师SFC注册编号（香港证监会）';
comment on column public.analyst.is_active is '是否在职：true=在职，false=离职';
comment on column public.analyst.created_at is '创建时间（UTC）';
comment on column public.analyst.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- sector 表
-- ============================================================
comment on table public.sector is '行业分类表：存储两级行业分类体系（level=1一级/level=2二级），通过parent_id建立层级关系';
comment on column public.sector.id is '主键UUID';
comment on column public.sector.level is '层级：1=一级行业，2=二级行业';
comment on column public.sector.parent_id is '父级行业ID（level=1时必须为空，level=2时必须引用level=1的记录）';
comment on column public.sector.name_en is '行业英文名称';
comment on column public.sector.name_cn is '行业中文名称';
comment on column public.sector.wind_name is 'Wind万得行业名称（用于与Wind数据对接）';
comment on column public.sector.is_active is '是否启用：true=启用，false=禁用';
comment on column public.sector.created_at is '创建时间（UTC）';
comment on column public.sector.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- coverage 表
-- ============================================================
comment on table public.coverage is '公司覆盖表：存储被研究覆盖的上市公司基本信息';
comment on column public.coverage.id is '主键UUID';
comment on column public.coverage.ticker is '股票代码（唯一，存储时统一处理大小写和空格）';
comment on column public.coverage.english_full_name is '公司英文全称';
comment on column public.coverage.chinese_short_name is '公司中文简称';
comment on column public.coverage.traditional_chinese is '公司繁体中文名称';
comment on column public.coverage.sector_id is '所属行业ID，关联sector.id，禁止删除已关联行业';
comment on column public.coverage.isin is 'ISIN国际证券识别码（唯一，存储时统一大写）';
comment on column public.coverage.country_of_domicile is '公司注册地/上市地';
comment on column public.coverage.reporting_currency is '报告使用货币';
comment on column public.coverage.ads_conversion_factor is 'ADS美股存托股折算因子';
comment on column public.coverage.is_duplicate is '是否重复记录';
comment on column public.coverage.approved_by is '审批人ID，关联auth.users，删除用户时置空';
comment on column public.coverage.approved_at is '审批时间';
comment on column public.coverage.is_active is '是否启用：true=启用，false=禁用';
comment on column public.coverage.created_at is '创建时间（UTC）';
comment on column public.coverage.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- coverage_analyst 表
-- ============================================================
comment on table public.coverage_analyst is '覆盖-分析师关系表：建立公司与分析师的覆盖关系，每公司最多4位分析师';
comment on column public.coverage_analyst.id is '主键UUID';
comment on column public.coverage_analyst.coverage_id is '覆盖公司ID，关联coverage.id，删除公司时级联删除';
comment on column public.coverage_analyst.analyst_id is '分析师ID，关联analyst.id，禁止删除已关联分析师';
comment on column public.coverage_analyst.role is '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';
comment on column public.coverage_analyst.sort_order is '排序序号（1-4），决定前端展示顺序，同公司内唯一';
comment on column public.coverage_analyst.created_at is '创建时间（UTC）';
comment on column public.coverage_analyst.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- template 表
-- ============================================================
comment on table public.template is '报告模板表：存储报告 Word 模板文件信息，每种报告类型+语言按 version 倒序取最新一条，不区分 report/model 类型';
comment on column public.template.id is '主键UUID';
comment on column public.template.name is '模板名称（如"公司报告模板v1"）';
comment on column public.template.report_type is '报告类型代码（如 company/sector/company_flash 等），值来自 report_type 表';
comment on column public.template.template_file_path is 'Word 模板文件存储路径（Supabase Storage templates bucket 下的路径），非空时表示模板文件已上传';
comment on column public.template.schema_file_path is 'Word schema 描述文件存储路径（Supabase Storage 下的 JSON 文件路径），描述模板所需的字段名称、位置和特征，可为空';
comment on column public.template.version is '版本号（>=1），同一 (report_type, language) 内递增，每次上传新版本时自动分配';
comment on column public.template.sort is '排序序号（整数，数字越小越靠前），用于 Templates 列表排序';
comment on column public.template.uploaded_by is '上传人ID，关联 auth.users，初始化占位模板允许为空';
comment on column public.template.language is '模板语言：en=英文模板，zh=中文模板';
comment on column public.template.created_at is '创建时间（UTC）';
comment on column public.template.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- report 表
-- ============================================================
comment on table public.report is '研究报告主表：存储报告的核心信息，支持草稿/提交/发布/驳回状态流转';
comment on column public.report.id is '主键UUID';
comment on column public.report.owner_user_id is '报告所有者用户ID，关联auth.users，创建后不可变更';
comment on column public.report.title is '报告标题';
comment on column public.report.report_type is '报告类型代码（如company/sector/company_flash等），合法值由template.report_type驱动';
comment on column public.report.status is '报告状态：draft=草稿，submitted=已提交待审核，published=已发布，rejected=已驳回';
comment on column public.report.current_version_no is '当前版本号（>=0），每次内容更新递增';
comment on column public.report.coverage_id is '关联公司ID，关联coverage.id，删除公司时置空';
comment on column public.report.sector_id is '关联行业ID，关联sector.id，删除行业时置空';
comment on column public.report.region_code is '报告覆盖区域代码，关联region.code，删除区域时置空';
comment on column public.report.published_by is '发布人ID，关联auth.users，仅在published状态时记录';
comment on column public.report.published_at is '发布时间，仅在published状态时记录';
comment on column public.report.created_at is '创建时间（UTC）';
comment on column public.report.updated_at is '最后更新时间（UTC）';
comment on column public.report.ticker is '关联股票代码';
comment on column public.report.rating is '投资评级（如OUTPERFORM/NEUTRAL等）';
comment on column public.report.target_price is '目标价（numeric类型，必须大于0）';
comment on column public.report.report_language is '报告语言：zh=中文，en=英文';
comment on column public.report.contact_person_id is '联系人ID，关联auth.users';
comment on column public.report.investment_thesis is '投资要点摘要';
comment on column public.report.certificate_confirmed is '证书确认状态：true=已确认，false=未确认';

-- ============================================================
-- report_version 表
-- ============================================================
comment on table public.report_version is '报告版本表（append-only）：记录报告每次提交的快照和文件信息，不允许修改或删除';
comment on column public.report_version.id is '主键UUID';
comment on column public.report_version.report_id is '所属报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_version.version_no is '版本号（>=1），同一报告内递增';
comment on column public.report_version.snapshot_json is '报告内容快照（JSONB），包含标题、类型、评级、目标价、分析师等核心字段';
comment on column public.report_version.word_file_path is 'Word/PPT文件存储路径（Supabase Storage）';
comment on column public.report_version.pdf_file_path is 'PDF文件存储路径（Supabase Storage）';
comment on column public.report_version.model_file_path is '模型文件存储路径（Supabase Storage）';
comment on column public.report_version.word_file_name is 'Word/PPT原始文件名（含扩展名）';
comment on column public.report_version.pdf_file_name is 'PDF原始文件名（含扩展名）';
comment on column public.report_version.model_file_name is '模型原始文件名（含扩展名）';
comment on column public.report_version.changed_by is '变更人ID，关联auth.users';
comment on column public.report_version.changed_at is '变更时间';
comment on column public.report_version.created_at is '创建时间（UTC）';

-- ============================================================
-- report_analyst 表
-- ============================================================
comment on table public.report_analyst is '报告-分析师关系表：建立报告与分析师的作者关系';
comment on column public.report_analyst.id is '主键UUID';
comment on column public.report_analyst.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_analyst.analyst_id is '分析师ID，关联analyst.id，禁止删除已关联分析师';
comment on column public.report_analyst.role is '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';
comment on column public.report_analyst.sort_order is '排序序号（1-4），决定展示顺序，同报告内唯一';
comment on column public.report_analyst.created_at is '创建时间（UTC）';
comment on column public.report_analyst.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- report_status_log 表
-- ============================================================
comment on table public.report_status_log is '报告状态变更日志表（append-only）：记录报告所有状态流转历史，不允许修改或删除';
comment on column public.report_status_log.id is '主键UUID';
comment on column public.report_status_log.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_status_log.from_status is '变更前状态';
comment on column public.report_status_log.to_status is '变更后状态';
comment on column public.report_status_log.action_by is '操作人ID，关联auth.users';
comment on column public.report_status_log.action_by_name is '操作人姓名（从analyst表冗余存储，避免删除用户后丢失）';
comment on column public.report_status_log.action_at is '操作时间';
comment on column public.report_status_log.reason is '驳回原因（仅to_status=rejected时必填），业务语义为批注Note';
comment on column public.report_status_log.version_no is '状态变更发生时的报告版本号';
comment on column public.report_status_log.created_at is '创建时间（UTC）';

-- ============================================================
-- email_subscription 表
-- ============================================================
comment on table public.email_subscription is '邮件订阅表：存储邮件订阅用户信息，支持按用户关联';
comment on column public.email_subscription.id is '主键UUID';
comment on column public.email_subscription.email is '订阅邮箱地址（唯一）';
comment on column public.email_subscription.user_id is '关联用户ID，关联auth.users，可为空（匿名订阅）';
comment on column public.email_subscription.is_active is '是否启用：true=启用，false=禁用';
comment on column public.email_subscription.created_at is '创建时间（UTC）';

-- ============================================================
-- email_config 表
-- ============================================================
comment on table public.email_config is '邮件配置表：存储SMTP服务器配置信息';
comment on column public.email_config.id is '主键UUID';
comment on column public.email_config.smtp_host is 'SMTP服务器地址';
comment on column public.email_config.smtp_port is 'SMTP服务器端口';
comment on column public.email_config.smtp_user is 'SMTP认证用户名';
comment on column public.email_config.smtp_pass is 'SMTP认证密码';
comment on column public.email_config.smtp_from is '发件人邮箱地址';
comment on column public.email_config.is_enabled is '是否启用：true=启用，false=禁用';
comment on column public.email_config.updated_at is '最后更新时间（UTC）';

-- ============================================================
-- report_distribution_queue 表
-- ============================================================
comment on table public.report_distribution_queue is '报告分发队列表：记录待分发的报告分发任务';
comment on column public.report_distribution_queue.id is '主键UUID';
comment on column public.report_distribution_queue.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_distribution_queue.status is '分发状态：pending=待处理，processing=处理中，completed=已完成，failed=失败';
comment on column public.report_distribution_queue.error_message is '错误信息（分发失败时记录）';
comment on column public.report_distribution_queue.scheduled_at is '计划执行时间';
comment on column public.report_distribution_queue.sent_at is '实际发送时间';
comment on column public.report_distribution_queue.created_at is '创建时间（UTC）';

-- ============================================================
-- report_distribution_history 表
-- ============================================================
comment on table public.report_distribution_history is '报告分发历史表：记录报告发送给各收件人的历史';
comment on column public.report_distribution_history.id is '主键UUID';
comment on column public.report_distribution_history.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_distribution_history.recipient_email is '收件人邮箱地址';
comment on column public.report_distribution_history.status is '发送状态：sent=已发送，failed=发送失败';
comment on column public.report_distribution_history.sent_at is '发送时间';
comment on column public.report_distribution_history.error_message is '错误信息（发送失败时记录）';
comment on column public.report_distribution_history.created_at is '创建时间（UTC）';

-- ============================================================
-- 公共函数注释
-- ============================================================
comment on function public.set_updated_at_utc() is '触发器函数：自动将updated_at字段更新为当前UTC时间';
comment on function public.current_app_role() is '获取当前用户的应用角色（从JWT的app_metadata.role读取）';
comment on function public.report_status_is_valid(text, text) is '验证报告状态转换是否合法：draft->submitted, submitted->published/rejected, rejected->draft';
comment on function public.get_user_full_name(uuid) is '根据用户ID获取用户在auth.users中的full_name';
comment on function public.validate_sector_hierarchy() is '触发器函数：验证行业分类层级结构合法性（两级，禁止循环，禁止跨级引用）';
comment on function public.validate_coverage_analyst_limit() is '触发器函数：验证每个coverage最多关联4位分析师';
comment on function public.report_enforce_owner_immutable() is '触发器函数：禁止修改报告的owner_user_id';
comment on function public.report_enforce_status_transition() is '触发器函数：验证报告状态转换合法性';
comment on function public.report_status_log_enforce_transition() is '触发器函数：验证状态日志记录的状态转换合法性';
comment on function public.prevent_update_delete_append_only() is '触发器函数：禁止对append-only表的UPDATE和DELETE操作';
comment on function public.report_save_content_atomic(uuid, text, text, text, text, numeric, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text) is '原子化保存报告内容的RPC函数：在单事务内更新报告基本信息、作者关系和版本快照';
comment on function public.report_change_status_atomic(uuid, text, uuid, text) is '原子化变更报告状态的RPC函数：在单事务内更新状态并写入状态日志';
comment on function public.add_to_distribution_queue(uuid) is '将报告添加到分发队列（幂等操作）';
comment on function public.get_active_subscription_emails() is '获取所有启用状态的订阅邮箱列表';

-- ============================================================
-- auth.users 表注释（Supabase托管，仅添加注释说明）
-- ============================================================
comment on table auth.users is 'Supabase托管认证用户表：存储系统所有用户账户信息，字段定义参见Supabase官方文档';

-- ============================================================
-- storage.objects 表注释（Supabase Storage）
-- ============================================================
comment on table storage.objects is 'Supabase Storage对象表：存储所有上传文件元数据，字段定义参见Supabase Storage文档';
