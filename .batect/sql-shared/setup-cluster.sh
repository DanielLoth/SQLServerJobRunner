#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

/sql-shared/delete-cert-files.sh

export Node1="$NODE1_HOSTNAME,1433"
export Node2="$NODE2_HOSTNAME,1433"

export AdminUser="sa"
export AdminPassword="$MSSQL_SA_PASSWORD"

export LoginName="$MSSQL_HADR_LOGIN_NAME"
export LoginPassword="$MSSQL_HADR_LOGIN_PASSWORD"
export UserName="$MSSQL_HADR_LOGIN_NAME"
sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-login.sql"
sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-user.sql"
sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-login.sql"
sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-user.sql"

sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/restore-backup.sql"
