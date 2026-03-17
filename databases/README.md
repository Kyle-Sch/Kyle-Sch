# Databases

Query examples and schema definitions for the database technologies used across projects.

## Contents

| Directory | Technology | Description |
|-----------|-----------|-------------|
| `kql/` | Azure Data Explorer (Kusto) | Time-series analytics, joins, anomaly detection |
| `neo4j/` | Neo4j (Cypher) | Graph traversal, relationship queries, shortest path |
| `relational/` | SQL Server / PostgreSQL | Normalized schema, indexes, stored procedure |

## Notes

- KQL queries assume an ADX cluster with a `Telemetry` database containing `Events` and `Metrics` tables.
- Cypher queries target a Neo4j 5.x instance with a supply-chain graph model.
- SQL schema targets SQL Server 2019+ / PostgreSQL 15+ (ANSI-compatible with minor dialect notes).
