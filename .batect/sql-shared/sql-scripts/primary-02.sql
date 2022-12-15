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
