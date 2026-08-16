-- Ingestion bookkeeping: what was fetched, when, and with what result (FR-REF-3/4),
-- plus the staging tables the peak import parses into before merging into [ref].
--
-- Rebuildable in full: nothing here survives that could not be produced by re-running
-- ingestion against the published datasets, which is why this schema is excluded from
-- the backup policy (README.md).
CREATE SCHEMA ingest;
