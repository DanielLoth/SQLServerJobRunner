create login [$(LoginName)]
with
    password = '$(LoginPassword)',
    default_database = [master],
    check_expiration = off,
    check_policy = off;
