#!/bin/bash
#
# This script configures a Gentoo system to use the binary packages and settings
# defined in this project. It is intended to be run on client systems (Gentoo systems)
# that will consume the binary packages.
#
# Usage: ConfigureSystem.sh <configuration_prefix>
#
# Arguments:
#   <configuration_prefix>: The directory containing the configuration to apply.
#                           This corresponds to a directory in the repository (e.g., '2').
#
# The script performs the following actions:
# 1. Checks if a configuration prefix is provided.
# 2. Sources 'variables.sh' from the current directory (expected to contain environment variables).
# 3. Removes existing Portage configuration directories to ensure a clean slate.
#    This includes package.use, package.env, repos.conf, etc.
# 4. Copies the new configuration files from the specified prefix directory to the root (/).
#
# Note: This script is destructive to the existing Portage configuration in the specified directories.

set -e

SCRIPT_DIR="$(dirname "$(readlink --canonicalize "$0")")"

if [ -z "$1" ]; then
    echo "Please specify a configuration prefix."
    exit 1
fi

# Clean up some configuration directories to ensure that they don't include deleted files.
# This removes old Portage configs, kernel configs, and SSH keys.
# The list of paths is maintained in cleanup-paths.txt, shared with scripts/SetConfiguration.ps1.
while IFS= read -r path; do
    [ -z "$path" ] && continue
    rm --force --recursive "/${path:?}"
done < "$SCRIPT_DIR/../cleanup-paths.txt"

# Copy the new configuration files from the specified prefix directory to the root (/).
# This applies the new Portage configuration, kernel config, and other settings.
cp --force --recursive "${SCRIPT_DIR}/../$1"/* /

# Set up the binary package signing verification keyring.
# This imports the project's signing public key so Portage can verify signed packages.
# Remove any pre-existing keyring first — getuto creates it as portage-owned, but GPG
# verification runs as root and requires root ownership.
PUBLIC_KEY="${SCRIPT_DIR}/../keys/binpkg-signing.asc"

echo "Setting up binary package signature verification..."

rm --force --recursive /etc/portage/gnupg
getuto

# Import the signing public key into the Portage verification keyring.
gpg --homedir=/etc/portage/gnupg --batch --import "$PUBLIC_KEY"

# Trust the imported key — extract its fingerprint and set trust to ultimate.
SIGNING_FPR=$(gpg --homedir=/etc/portage/gnupg --with-colons --fingerprint --list-keys "bookish-spork@compact-orb" | awk -F: '/^fpr:/{print $10; exit}')
if [ -n "$SIGNING_FPR" ]; then
    echo "${SIGNING_FPR}:6:" | gpg --homedir=/etc/portage/gnupg --batch --import-ownertrust
    gpg --homedir=/etc/portage/gnupg --check-trustdb
fi

echo "Signing key imported and trusted."
