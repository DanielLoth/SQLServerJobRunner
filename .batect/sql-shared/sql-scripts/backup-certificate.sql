backup certificate [$(CertificateName)]
to file = '$(CertificateFile)'
with private key (
    file = '$(PrivateKeyFile)',
    encryption by password = '$(CertificatePassword)'
);
