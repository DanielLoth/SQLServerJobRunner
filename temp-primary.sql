:setvar NODE1_HOSTNAME "s2022n1"
:setvar NODE2_HOSTNAME "s2022n2"
:setvar MASTER_KEY_PASSWORD "NowYouSitLikeACobwebCatchingTheWind2020"
:setvar HADR_LOGIN_NAME "hadr_login"
:setvar HADR_LOGIN_PASSWORD "RunningThroughTheFireRunningThroughTheFlame2010"
:setvar HADR_USER_NAME "hadr_user"
:setvar HADR_CERT_NAME "hadr_cert"
:setvar HADR_CERT_PASSWORD "DoILookThankfulToYou2022"
:setvar HADR_CERT_FILE "/sql-shared/certificate/cert.cert"
:setvar HADR_CERT_PRIVATE_KEY_FILE "/sql-shared/certificate/cert.key"
:setvar HADR_ENDPOINT_NAME "hadr_endpoint"
:setvar HADR_ENDPOINT_PORT 5022
:setvar HADR_AG_NAME "AG1"

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










:setvar NODE1_HOSTNAME "s2022n1"
:setvar NODE2_HOSTNAME "s2022n2"
:setvar MASTER_KEY_PASSWORD "NowYouSitLikeACobwebCatchingTheWind2020"
:setvar HADR_LOGIN_NAME "hadr_login"
:setvar HADR_LOGIN_PASSWORD "RunningThroughTheFireRunningThroughTheFlame2010"
:setvar HADR_USER_NAME "hadr_user"
:setvar HADR_CERT_NAME "hadr_cert"
:setvar HADR_CERT_PASSWORD "DoILookThankfulToYou2022"
:setvar HADR_CERT_FILE "/sql-shared/certificate/cert.cert"
:setvar HADR_CERT_PRIVATE_KEY_FILE "/sql-shared/certificate/cert.key"
:setvar HADR_ENDPOINT_NAME "hadr_endpoint"
:setvar HADR_ENDPOINT_PORT 5022
:setvar HADR_AG_NAME "AG1"

create availability group [$(HADR_AG_NAME)]
with (
    cluster_type = none
)
for replica on
N'$(NODE1_HOSTNAME)' with
(
    endpoint_url = N'tcp://$(NODE1_HOSTNAME):$(HADR_ENDPOINT_PORT)',
    availability_mode = synchronous_commit,
    seeding_mode = automatic,
    failover_mode = manual,
    secondary_role (allow_connections = all)
),
N'$(NODE2_HOSTNAME)' with
(
    endpoint_url = N'tcp://$(NODE2_HOSTNAME):$(HADR_ENDPOINT_PORT)',
    availability_mode = synchronous_commit,
    seeding_mode = automatic,
    failover_mode = manual,
    secondary_role (allow_connections = all)
);
go
