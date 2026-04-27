CREATE INDEX "cluster_events_at_idx" ON "kong"."cluster_events" (at);
CREATE INDEX "cluster_events_expire_at_idx" ON "kong"."cluster_events" (expire_at);
CREATE INDEX "cluster_events_channel_idx" ON "kong"."cluster_events" (channel);