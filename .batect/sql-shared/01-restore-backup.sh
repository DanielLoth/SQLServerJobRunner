#!/bin/sh
set -e

export PATH="$PATH:/opt/mssql-tools/bin/"

sqlcmd -U sa -S "localhost,1433" -P $MSSQL_SA_PASSWORD -i /sql-shared/sql-scripts/01-restore-backup.sql

