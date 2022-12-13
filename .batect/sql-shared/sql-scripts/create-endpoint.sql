create endpoint [$(EndpointName)]
state = started
as tcp (
    listener_port = $(ListenerPort),
    listener_ip = all
)
for data_mirroring (
    role = all,
    authentication = certificate $(CertificateName)
    encryption = required algorithm aes
);

grant connect on endpoint::[$(EndpointName)] to [$(LoginName)];
