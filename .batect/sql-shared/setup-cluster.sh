#!/bin/bash
set -o pipefail

export PATH="$PATH:/opt/mssql-tools/bin/"

rm -f $HADR_CERT_FILE 2> /dev/null
rm -f $HADR_CERT_PRIVATE_KEY_FILE 2> /dev/null

export Node1="$NODE1_HOSTNAME,1433"
export Node2="$NODE2_HOSTNAME,1433"

# sqlcmd -S $Node1 -U "sa" -P $MSSQL_SA_PASSWORD -N -C -d master -i "/sql-shared/sql-scripts/primary-01.sql"
# sqlcmd -S $Node2 -U "sa" -P $MSSQL_SA_PASSWORD -N -C -d master -i "/sql-shared/sql-scripts/secondary-01.sql"
# sqlcmd -S $Node1 -U "sa" -P $MSSQL_SA_PASSWORD -N -C -d master -i "/sql-shared/sql-scripts/primary-02.sql"

# export Node1="$NODE1_HOSTNAME,1433"
# export Node2="$NODE2_HOSTNAME,1433"

# export AdminUser="sa"
# export AdminPassword="$MSSQL_SA_PASSWORD"

# export LoginName="$HADR_LOGIN_NAME"
# export LoginPassword="$HADR_LOGIN_PASSWORD"
# export UserName="$HADR_USER_NAME"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-login.sql"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-user.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-login.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-user.sql"

# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/restore-backup.sql"

# export MasterKeyPassword="$MASTER_KEY_PASSWORD"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-master-key.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-master-key.sql"

# export CertificateName="$HADR_CERT_NAME"
# export CertificateFile="$HADR_CERT_FILE"
# export PrivateKeyFile="$HADR_CERT_PRIVATE_KEY_FILE"
# export CertificatePassword="$HADR_CERT_PASSWORD"
# rm -f $CertificateFile 2> /dev/null
# rm -f $PrivateKeyFile 2> /dev/null
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-certificate.sql"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/backup-certificate.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-certificate-from-file.sql"

# export EndpointName="$HADR_ENDPOINT_NAME"
# export ListenerPort="$HADR_ENDPOINT_PORT"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-endpoint.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-endpoint.sql"

# export AGName="$HADR_AG_NAME"
# export AGNode1="$NODE1_HOSTNAME"
# export AGNode2="$NODE2_HOSTNAME"
# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/create-availability-group.sql"
# sqlcmd -S $Node2 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/join-availability-group.sql"

# sqlcmd -S $Node1 -U $AdminUser -P $AdminPassword -N -C -d master -i "/sql-shared/sql-scripts/add-database-to-availability-group.sql"
