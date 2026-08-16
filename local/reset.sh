#!/usr/bin/env bash
#
# Rebuild the local Rekfar database from scratch: start the container, drop and recreate
# the database with the Norwegian collation, then publish the current schema.
#
# Requires: docker, the .NET SDK, and the SqlPackage tool
#     dotnet tool install --global microsoft.sqlpackage
#
# Usage:
#     local/reset.sh              # rebuild
#     local/reset.sh --smoke      # rebuild, then run tests/smoke.sql
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DB_NAME="Rekfar"
COLLATION="Norwegian_100_CI_AS"
SQLCMD=(/opt/mssql-tools18/bin/sqlcmd -C -b -S localhost -U sa)
RUN_SMOKE=0

for arg in "$@"; do
    case "$arg" in
        --smoke) RUN_SMOKE=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

if [[ ! -f local/.env ]]; then
    echo "local/.env is missing. Copy local/.env.example and set a password." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a; source local/.env; set +a

echo "==> Starting SQL Server"
docker compose --env-file local/.env -f local/docker-compose.yml up -d --wait

exec_sql() {
    docker compose -f local/docker-compose.yml exec -T sql "${SQLCMD[@]}" -P "$MSSQL_SA_PASSWORD" "$@"
}

# The collation is set here, at creation, because Azure SQL cannot change it afterwards
# and local development is worth nothing if it sorts and compares differently.
echo "==> Recreating database $DB_NAME ($COLLATION)"
exec_sql -Q "
    IF DB_ID('$DB_NAME') IS NOT NULL
    BEGIN
        ALTER DATABASE [$DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [$DB_NAME];
    END
    CREATE DATABASE [$DB_NAME] COLLATE $COLLATION;
"

echo "==> Building the schema"
dotnet build src/Rekfar.Database --configuration Release --nologo

echo "==> Publishing to $DB_NAME"
sqlpackage /Action:Publish \
    /SourceFile:"src/Rekfar.Database/bin/Release/Rekfar.Database.dacpac" \
    /Profile:"publish/local.publish.xml" \
    /TargetServerName:"localhost,1433" \
    /TargetDatabaseName:"$DB_NAME" \
    /TargetUser:"sa" \
    /TargetPassword:"$MSSQL_SA_PASSWORD" \
    /TargetEncryptConnection:True \
    /TargetTrustServerCertificate:True

if [[ $RUN_SMOKE -eq 1 ]]; then
    echo "==> Running smoke tests"
    docker compose -f local/docker-compose.yml cp tests/smoke.sql sql:/tmp/smoke.sql
    exec_sql -d "$DB_NAME" -i /tmp/smoke.sql
fi

echo "==> Done. Connect with: sa / \$MSSQL_SA_PASSWORD at localhost,1433, database $DB_NAME"
