# keys/

This directory holds the signing keys used for binary package verification and Secure Boot.

## Files

- `binpkg-signing.asc` — OpenPGP public key for binary package verification. Clients import this to verify signed packages.
- `secureboot-db.cer` — DER-format Secure Boot signing certificate. Clients import this to trust CI-signed kernels and modules.

## OpenPGP Signing Key

Generate the signing key:

```bash
gpg --batch --generate-key <<EOF
%no-protection
Key-Type: EdDSA
Key-Curve: ed25519
Key-Usage: sign
Name-Real: bookish-spork binpkg signing
Name-Email: bookish-spork@compact-orb
Expire-Date: 0
EOF
```

Export:

```bash
# Private key -> GitHub secret (BINPKG_GPG_SIGNING_KEY_BASE64)
gpg --export-secret-keys "bookish-spork@compact-orb" | base64 -w0

# Public key -> this directory
gpg --export --armor "bookish-spork@compact-orb" > keys/binpkg-signing.asc
```

## Secure Boot Signing Key

Generate the key pair (RSA-2048, valid 10 years):

```bash
openssl req -new -x509 -newkey rsa:2048 -keyout db.key -out db.pem \
  -nodes -days 3650 -subj "/CN=bookish-spork Secure Boot Signing Key"
```

Export:

```bash
# Private key -> GitHub secret (SECUREBOOT_DB_KEY_BASE64)
base64 -w0 < db.key

# Certificate -> GitHub secret (SECUREBOOT_DB_CERT_BASE64)
base64 -w0 < db.pem

# DER certificate -> this directory (for client enrollment)
openssl x509 -in db.pem -outform DER -out keys/secureboot-db.cer
```

Client enrollment (one-time):

```bash
sudo mokutil --import keys/secureboot-db.cer
# Reboot -> confirm in MokManager -> enable Secure Boot in UEFI settings
```
