#!/bin/bash
#
# This script is a wrapper around the Gentoo Portage `emerge` command.
# It handles bootstrapping, updating, and installing packages within the
# Gentoo environment. It supports resuming failed builds, syncing the
# portage tree, and managing binary package repositories.
#
set -e

# 5 hours and 30 minutes in seconds. GitHub Actions job timeout is 6 hours.
TIMEOUT=19800

LONG_OPTS=packages:,update,resume,sync,bootstrap:,portage-profile,usepkg-exclude:,bootstrap-binrepos-architecture:

eval set -- "$(getopt --longoptions "$LONG_OPTS" --name "$0" --options "" -- "$@")" || exit 1

# List of packages to install
packages=""

# Flag to indicate if we should update @world
update=0

# Flag to indicate if we should resume a failed emerge
resume=0

# Flag to indicate if we should sync the portage tree
sync_flag=0

# Bootstrap mode: 0=Normal, 1=Step 1 (Setup), 2=Step 2 (Rebuild)
bootstrap=0

# Portage profile to set during bootstrap step 1
portage_profile=""

# List of packages to exclude from usepkg
usepkg_exclude=""

# Architecture to use for bootstrap binrepos
bootstrap_binrepos_architecture=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --packages)
            packages+=" $2"
            shift 2
            ;;
        --update)
            update=1
            shift
            ;;
        --resume)
            resume=1
            shift
            ;;
        --sync)
            sync_flag=1
            shift
            ;;
        --bootstrap)
            bootstrap=$2
            shift 2
            ;;
        --portage-profile)
            portage_profile=$2
            shift 2
            ;;
        --usepkg-exclude)
            usepkg_exclude+=" $2"
            shift 2
            ;;
        --bootstrap-binrepos-architecture)
            bootstrap_binrepos_architecture=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            exit 2
            ;;
    esac
done

if [[ $# -gt 0 ]]; then
    packages+=" $*"
fi

packages=$(echo "$packages" | xargs echo)

usepkg_exclude=$(echo "$usepkg_exclude" | xargs echo)

case $bootstrap_binrepos_architecture in
    "amd64")
        bootstrap_binrepos_profile="x86-64"
        ;;
    "arm64")
        bootstrap_binrepos_profile="arm64"
        ;;
    *)
        if (( bootstrap == 1 )); then
            exit 3
        fi
        ;;
esac

# Wrapper function for emerge with a timeout
# usage: t_emerge [emerge_options] [packages]
t_emerge() {
    local cmd_prefix=()

    cmd_prefix=(timeout "$TIMEOUT")

    "${cmd_prefix[@]}" emerge "$@"
}

# Helper function to write content to a file
# usage: write_file <filename> <content>
write_file() {
    printf '%b\n' "$2" > "$1"
}

case $bootstrap in
    1)
        # Bootstrap Step 1: Initial Setup
        # This step sets up the basic environment, including the portage profile,
        # This step is specific to the current configuration (LLVM, PyPy emerge, Rust, etc).
        # If you change the configuration, you may need to update this step.
        emerge-webrsync

        if [[ -n $portage_profile ]]; then
            eselect --brief profile set "$portage_profile"
        fi

        mkdir /etc/portage/binrepos.conf

        write_file /etc/portage/binrepos.conf/bootstrap.conf "[binhost]\npriority = 9999\nsync-uri = http://distfiles.gentoo.org/releases/${bootstrap_binrepos_architecture}/binpackages/23.0/${bootstrap_binrepos_profile}/"

        mv /etc/python-exec/emerge.conf /tmp/emerge.conf.backup

        write_file /etc/portage/package.use/bootstrap "*/* -jemalloc -tcmalloc\nnet-libs/nghttp2 xml"

        FEATURES="binpkg-request-signature" emerge --binpkg-respect-use=n --getbinpkgonly --nodeps dev-lang/rust dev-vcs/git llvm-core/clang

        write_file /etc/portage/package.env/bootstrap "dev-lang/pypy gcc.conf"

        emerge --buildpkg=n --getbinpkg dev-lang/pypy

        rm /etc/portage/package.env/bootstrap

        emerge --buildpkg=n --getbinpkg --oneshot llvm-core/clang-common llvm-core/clang-linker-config llvm-runtimes/clang-runtime

        emerge --buildpkg=n --deep --oneshot sys-apps/portage

        mv /tmp/emerge.conf.backup /etc/python-exec/emerge.conf

        emerge --buildpkg=n --oneshot dev-lang/perl

        emerge --sync

        rm /etc/portage/binrepos.conf/bootstrap.conf

        rmdir /etc/portage/binrepos.conf

        rm --force --recursive /var/cache/binpkgs/*

        rm /etc/portage/package.use/bootstrap
        ;;
    2)
        # Bootstrap Step 2: System Rebuild
        # This step rebuilds the entire system (@world) with an empty tree to ensure
        # all packages are built with the configured flags and profile.
        if (( resume )); then
            t_emerge --emptytree --resume
        else
            t_emerge --emptytree "@world"
        fi

        emerge --depclean
        ;;
    0)
        # Normal Operation
        # This mode handles syncing, updating the system, or installing specific packages.
        if   (( sync_flag )); then
            emerge --sync
        elif (( update )) && [[ -z "$packages" ]]; then
            t_emerge --deep --newuse --update "@world"

            emerge --depclean
        else
            declare -a opts

            (( resume )) && opts+=( --resume )

            (( update )) && opts+=( --update --deep --newuse )

            [[ -n "$usepkg_exclude" ]] && opts+=( --usepkg-exclude "${usepkg_exclude}" )

            read -ra PKG_ARR <<< "$packages"

            t_emerge "${opts[@]}" "${PKG_ARR[@]}"

            emerge --depclean
        fi
        ;;
    *)
        exit 4
        ;;
esac
