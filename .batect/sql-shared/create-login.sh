#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

# echo $1
# echo $MSSQL_HADR_LOGIN_NAME
# echo $MSSQL_HADR_LOGIN_PASSWORD
# echo $MSSQL_HADR_USER_NAME

export Server=$1
export LoginName=$2
export LoginPassword=$3

echo Server = $Server
echo Login name = $LoginName
echo Password = $LoginPassword

sqlcmd -S $Server -U "sa" -P $MSSQL_SA_PASSWORD -N -C -d master \
    -i "/sql-shared/sql-scripts/create-login.sql"
