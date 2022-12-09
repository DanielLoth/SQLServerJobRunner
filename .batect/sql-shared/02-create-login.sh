#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

sqlcmd \
    -U sa \
    -S "$NODE1_HOSTNAME,1433" \
    -P $MSSQL_SA_PASSWORD \
    -d master \
    -i /sql-shared/sql-scripts/02-create-login.sql \
    -v MSSQL_HADR_LOGIN_NAME="$MSSQL_HADR_LOGIN_NAME" \
    -v MSSQL_HADR_LOGIN_PASSWORD="$MSSQL_HADR_LOGIN_PASSWORD" \
    -v MSSQL_HADR_USER_NAME="$MSSQL_HADR_USER_NAME"
