#!/bin/bash
# Creates a local, self-signed code-signing identity "Veil Local" in your login keychain, so macOS keeps
# Veil Search's permissions (Contacts, Calendar, Automation, Accessibility) across rebuilds. Run once, by you.
set -euo pipefail
security find-certificate -c "Veil Local" >/dev/null 2>&1 && { echo "already exists"; exit 0; }
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
cat > "$w/cfg" <<CFG
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=Veil Local
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CFG
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$w/k.pem" -out "$w/c.pem" -days 3650 -config "$w/cfg" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$w/k.pem" -in "$w/c.pem" -out "$w/id.p12" -passout pass:nc -name "Veil Local" 2>/dev/null
security import "$w/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P nc -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$w/c.pem"  # asks for your password
echo "Created. Rebuild with: ~/.config/veil/launcher/build.sh"
