INSERT INTO "_analytics"."endpoint_queries" ("id", "name", "token", "query", "user_id", "inserted_at", "updated_at", "source_mapping", "sandboxable", "cache_duration_seconds", "proactive_requerying_seconds", "max_limit", "enable_auth", "language", "description", "sandbox_query_id", "labels", "backend_id", "redact_pii") VALUES 
('1', 'logs.all', '354e1b6b-1a4d-4e4e-af65-42ef6dc5185f', 'with edge_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `cloudflare.logs.prod` as t
  cross join unnest(metadata) as m
where
  -- order of the where clauses matters
  -- project then timestamp then everything else
  t.project = @project
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
order by
  cast(t.timestamp as timestamp) desc
),

postgres_logs as (
  select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata
from `postgres.logs` as t
where
  -- order of the where clauses matters
  -- project then timestamp then everything else
  t.project = @project
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
  order by cast(t.timestamp as timestamp) desc
),

function_edge_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `deno-relay-logs` as t
  cross join unnest(t.metadata) as m
where
  CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
  and m.project_ref = @project
order by cast(t.timestamp as timestamp) desc
),

function_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `deno-subhosting-events` as t
  cross join unnest(t.metadata) as m
where
  -- order of the where clauses matters
  -- project then timestamp then everything else
  m.project_ref = @project
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
order by cast(t.timestamp as timestamp) desc
),

auth_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `gotrue.logs.prod` as t
  cross join unnest(t.metadata) as m
where
  -- order of the where clauses matters
  -- project then timestamp then everything else
  -- m.project = @project
  t.project = @project
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
order by cast(t.timestamp as timestamp) desc
),

realtime_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `realtime.logs.prod` as t
  cross join unnest(t.metadata) as m
where
  m.project = @project 
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
order by cast(t.timestamp as timestamp) desc
),

storage_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `storage.logs.prod.2` as t
  cross join unnest(t.metadata) as m
where
  m.project = @project
  AND CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
order by cast(t.timestamp as timestamp) desc
),

postgrest_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `postgREST.logs.prod` as t
  cross join unnest(t.metadata) as m
where
  CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
  AND t.project = @project
order by cast(t.timestamp as timestamp) desc
),

pgbouncer_logs as (
select 
  t.timestamp,
  t.id, 
  t.event_message, 
  t.metadata 
from `pgbouncer.logs.prod` as t
  cross join unnest(t.metadata) as m
where
  CASE WHEN COALESCE(@iso_timestamp_start, '''') = '''' THEN  TRUE ELSE  cast(t.timestamp as timestamp) > cast(@iso_timestamp_start as timestamp) END
  AND CASE WHEN COALESCE(@iso_timestamp_end, '''') = '''' THEN TRUE ELSE cast(t.timestamp as timestamp) <= cast(@iso_timestamp_end as timestamp) END
  AND t.project = @project
order by cast(t.timestamp as timestamp) desc
)

SELECT id, timestamp, event_message, metadata
FROM edge_logs
LIMIT 100', '1', '2026-03-18 08:46:57', '2026-03-18 08:46:57', '{"postgres.logs": "9636912e-58e3-4fb3-9fb6-0f69593d0830", "deno-relay-logs": "bb7d9bf2-7572-41a6-8a08-4fe21e8e7553", "gotrue.logs.prod": "398567bf-8167-4614-89f3-49f50b97cc26", "realtime.logs.prod": "1ed51b71-3dde-4fc3-b2f8-2ad439872c9a", "pgbouncer.logs.prod": "85b1c218-0426-4722-a412-32f7fb094224", "postgREST.logs.prod": "5ca6fb13-dff4-4a2a-9032-09f23228c657", "storage.logs.prod.2": "4308f5bc-8ac8-4818-87f2-5a31d5fa37d0", "cloudflare.logs.prod": "59cfa256-b86c-409e-aeb0-b460667ed0a5", "deno-subhosting-events": "01e46b5f-2794-4c03-87fb-2d654c0fff26"}', true, '0', '1800', '1000', true, 'bq_sql', null, null, null, null, false);
INSERT INTO "_analytics"."endpoint_queries" ("id", "name", "token", "query", "user_id", "inserted_at", "updated_at", "source_mapping", "sandboxable", "cache_duration_seconds", "proactive_requerying_seconds", "max_limit", "enable_auth", "language", "description", "sandbox_query_id", "labels", "backend_id", "redact_pii") VALUES 
('2', 'usage.api-counts', 'a404ccd3-50b3-4be9-a0bf-41709354e1c7', 'with 
dates as (
  select (case
    when @interval = ''hourly'' then timestamp_sub(current_timestamp(), interval 1 hour)
    when @interval = ''daily'' then timestamp_sub(current_timestamp(), interval 7 day)
    when @interval = ''minutely'' then timestamp_sub(current_timestamp(), interval 60 minute)
  end) as start
),
chart_counts as (
select
  (case
    when @interval = ''hourly'' then timestamp_trunc(f0.timestamp,  hour)
    when @interval = ''daily'' then timestamp_trunc(f0.timestamp,  day)
    when @interval = ''minutely'' then timestamp_trunc(f0.timestamp,  minute)
  end
  ) as timestamp,
  COUNTIF(REGEXP_CONTAINS(f2.path, ''/rest'')) as total_rest_requests,
  COUNTIF(REGEXP_CONTAINS(f2.path, ''/storage'')) as total_storage_requests,
  COUNTIF(REGEXP_CONTAINS(f2.path, ''/auth'')) as total_auth_requests,
  COUNTIF(REGEXP_CONTAINS(f2.path, ''/realtime'')) as total_realtime_requests,
FROM
  dates, 
  `cloudflare.logs.prod` as f0
  LEFT JOIN UNNEST(metadata) AS f1 ON TRUE
  LEFT JOIN UNNEST(f1.request) AS f2 ON TRUE
where
  REGEXP_CONTAINS(f2.url, @project) AND f0.timestamp >= dates[0]
  -- project = @project
GROUP BY
    timestamp
)
SELECT
    datetime(chart_counts.timestamp, ''UTC'') as timestamp,
    COALESCE(SUM(chart_counts.total_rest_requests), 0) as total_rest_requests,
    COALESCE(SUM(chart_counts.total_storage_requests), 0) as total_storage_requests,
    COALESCE(SUM(chart_counts.total_auth_requests), 0) as total_auth_requests,
    COALESCE(SUM(chart_counts.total_realtime_requests), 0) as total_realtime_requests,
FROM  
  chart_counts
GROUP BY
    timestamp
ORDER BY
    timestamp asc;', '1', '2026-03-18 08:46:57', '2026-03-18 08:46:57', '{"cloudflare.logs.prod": "59cfa256-b86c-409e-aeb0-b460667ed0a5"}', true, '900', '300', '1000', true, 'bq_sql', null, null, null, null, false);
