#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

export Server="$SERVER_HOSTNAME,1433"
export AdminUser="sa"
export AdminPassword="$MSSQL_SA_PASSWORD"

sqlcmd -S $Server -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/restore-backup.sql"
