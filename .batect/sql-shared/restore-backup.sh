#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

sqlcmd \
    -U sa \
    -S "$NODE1_HOSTNAME,1433" \
    -P $MSSQL_SA_PASSWORD \
    -i /sql-shared/sql-scripts/restore-backup.sql
