set -e

TIMEOUT=19800

source /mnt/variables.sh

LONG_OPTS=packages:,update,resume,sync,bootstrap:,portage-profile:

eval set -- "$(getopt --longoptions "$LONG_OPTS" --name "$0" --options "" -- "$@")" || exit 1

packages=""

update=0

resume=0

sync_flag=0

bootstrap=0

portage_profile=""

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
        --)
            shift

            break
            ;;
        *)
            exit 1
            ;;
    esac
done

if [[ $# -gt 0 ]]; then
    packages+=" $*"
fi

packages=$(echo "$packages" | xargs echo)

t_emerge() {
    local cmd_prefix=()

    cmd_prefix=(timeout "$TIMEOUT")

    "${cmd_prefix[@]}" emerge "$@"
}

write_file() {
    printf '%b\n' "$2" > "$1"
}

case $bootstrap in
    1)
        emerge-webrsync

        if [[ -n $portage_profile ]]; then
            eselect --brief profile set "$portage_profile"
        fi

        mkdir /etc/portage/binrepos.conf

        write_file /etc/portage/binrepos.conf/bootstrap.conf "[binhost]\npriority = 9999\nsync-uri = http://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/"

        mv /etc/python-exec/emerge.conf /tmp/emerge.conf.backup

        FEATURES="binpkg-request-signature" emerge --binpkg-respect-use=n --getbinpkgonly dev-lang/pypy dev-lang/rust dev-vcs/git llvm-core/clang

        emerge --buildpkg=n --getbinpkg --oneshot llvm-core/clang-common llvm-core/clang-linker-config llvm-runtimes/clang-runtime

        emerge --buildpkg=n --deep --oneshot sys-apps/portage

        mv /tmp/emerge.conf.backup /etc/python-exec/emerge.conf

        emerge --buildpkg=n --oneshot dev-lang/perl

        emerge --sync

        rm /etc/portage/binrepos.conf/bootstrap.conf

        rmdir /etc/portage/binrepos.conf

        rm --force --recursive /var/cache/binpkgs/*
        ;;
    2)
        if (( resume )); then
            t_emerge --emptytree --resume
        else
            t_emerge --emptytree "@world"
        fi

        emerge --depclean
        ;;
    0)
        if   (( sync_flag )); then
            emerge --sync
        elif (( update )) && [[ -z "$packages" ]]; then
            t_emerge --deep --newuse --update "@world"

            emerge --depclean
        else
            declare -a opts

            (( resume )) && opts+=( --resume )

            (( update )) && opts+=( --update --deep --newuse )

            read -ra PKG_ARR <<< "$packages"

            t_emerge "${opts[@]}" "${PKG_ARR[@]}"

            emerge --depclean
        fi
        ;;
    *)
        exit 1
        ;;
esac
