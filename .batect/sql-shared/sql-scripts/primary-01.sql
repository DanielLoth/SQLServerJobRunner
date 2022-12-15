create login [$(HADR_LOGIN_NAME)]
with
    password = '$(HADR_LOGIN_PASSWORD)',
    default_database = [master],
    check_expiration = off,
    check_policy = off;
go

create user [$(HADR_USER_NAME)] for login [$(HADR_LOGIN_NAME)];
go

create master key encryption by password = '$(MASTER_KEY_PASSWORD)';
go

create certificate $(HADR_CERT_NAME) with subject = 'HADR certificate';
go

backup certificate [$(HADR_CERT_NAME)]
to file = '$(HADR_CERT_FILE)'
with private key (
    file = '$(HADR_CERT_PRIVATE_KEY_FILE)',
    encryption by password = '$(HADR_CERT_PASSWORD)'
);
go

create endpoint [$(HADR_ENDPOINT_NAME)]
state = started
as tcp (
    listener_port = $(HADR_ENDPOINT_PORT),
    listener_ip = all
)
for data_mirroring (
    role = all,
    authentication = certificate $(HADR_CERT_NAME),
    encryption = required algorithm aes
);
go

grant connect on endpoint::[$(HADR_ENDPOINT_NAME)] to [$(HADR_LOGIN_NAME)];
go
