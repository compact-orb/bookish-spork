# keys/

This directory holds the OpenPGP public key used for binary package signing.

## Files

- `binpkg-signing.asc` — The exported public key for binary package verification. Clients import this key to verify signed packages.

## Setup

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
# Private key → GitHub secret (BINPKG_GPG_SIGNING_KEY_BASE64)
gpg --export-secret-keys "bookish-spork@compact-orb" | base64 -w0

# Public key → this directory
gpg --export --armor "bookish-spork@compact-orb" > keys/binpkg-signing.asc
```
