use [master];

create login [$(MSSQL_HADR_LOGIN_NAME)]
with
    password = '$(MSSQL_HADR_LOGIN_PASSWORD)',
    default_database = [master],
    check_expiration = off,
    check_policy = off;

create user [$(MSSQL_HADR_USER_NAME)] for login [$(MSSQL_HADR_LOGIN_NAME)];
