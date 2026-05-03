#!/bin/bash
set -e

CERT_NAME="MacExplorer Dev"

echo "Creating self-signed code signing certificate: \"${CERT_NAME}\""
echo ""
echo "This will open Keychain Access to create the certificate."
echo "Follow these steps:"
echo "  1. Certificate Assistant will open"
echo "  2. Set 'Name' to: ${CERT_NAME}"
echo "  3. Set 'Certificate Type' to: Code Signing"
echo "  4. Click 'Create', then 'Continue', then 'Done'"
echo ""

# Create a self-signed certificate via the security command
# This creates it directly in the login keychain
cat > /tmp/macexplorer-cert.cfg << 'EOF'
[ req ]
default_bits       = 2048
distinguished_name = req_dn
prompt             = no
[ req_dn ]
CN = MacExplorer Dev
[ v3_code_signing ]
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
EOF

# Generate key and certificate
openssl req -x509 -newkey rsa:2048 -keyout /tmp/macexplorer-key.pem \
    -out /tmp/macexplorer-cert.pem -days 3650 -nodes \
    -config /tmp/macexplorer-cert.cfg -extensions v3_code_signing 2>/dev/null

# Import into login keychain as trusted code signing cert
security import /tmp/macexplorer-cert.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
security import /tmp/macexplorer-key.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign

# Trust the certificate for code signing
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db /tmp/macexplorer-cert.pem

# Cleanup
rm -f /tmp/macexplorer-cert.cfg /tmp/macexplorer-key.pem /tmp/macexplorer-cert.pem

echo ""
echo "Certificate '${CERT_NAME}' created and trusted!"
echo ""
echo "Verify with:"
echo "  security find-identity -v -p codesigning"
