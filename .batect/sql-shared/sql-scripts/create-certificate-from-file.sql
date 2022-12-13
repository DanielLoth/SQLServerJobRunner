create certificate [$(CertificateName)]
authorization [$(UserName)]
from file = '$(CertificateFile)'
with private key (
    file = '$(PrivateKeyFile)',
    decryption by password = '$(CertificatePassword)'
);
