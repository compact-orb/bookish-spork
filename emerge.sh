set -e

TIMEOUT=19800

source /mnt/variables.sh

LONG_OPTS=packages:,emptytree,keep-going,oneshot,usepkg-exclude:,no-quiet-build,keepwork,update,resume,deselect,sync,bootstrap:,portage-profile:,no-timeout

eval set -- "$(getopt --longoptions "$LONG_OPTS" --name "$0" --options "" -- "$@")" || exit 1

packages=""

emptytree=0

keep_going=0

oneshot=0

usepkg_exclude=""

no_quiet_build=0

keepwork=0

update=0

resume=0

deselect=0

sync_flag=0

bootstrap=0

portage_profile=""

no_timeout=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --packages)
            packages+=" $2"

            shift 2
            ;;
        --emptytree)
            emptytree=1

            shift
            ;;
        --keep-going)
            keep_going=1

            shift
            ;;
        --oneshot)
            oneshot=1

            shift
            ;;
        --usepkg-exclude)
            usepkg_exclude=$2

            shift 2
            ;;
        --no-quiet-build)
            no_quiet_build=1

            shift
            ;;
        --keepwork)
            keepwork=1

            shift
            ;;
        --update)
            update=1

            shift
            ;;
        --resume)
            resume=1

            shift
            ;;
        --deselect)
            deselect=1

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
        --no-timeout)
            no_timeout=1

            shift
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

    local features=""

    if (( ! no_timeout )); then
        cmd_prefix=(timeout "$TIMEOUT")
    fi

    if (( keepwork )); then
        features="FEATURES=keepwork"

        if (( ! resume )); then
            "${cmd_prefix[@]}" emerge --onlydeps "$@"
        fi
    fi

    if [[ -n "$features" ]]; then
        eval "${features} "'"${cmd_prefix[@]}" emerge "$@"'
    else
        "${cmd_prefix[@]}" emerge "$@"
    fi
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
        elif (( deselect )); then
            read -ra PKG_ARR <<< "$packages"

            emerge --deselect "${PKG_ARR[@]}"
        elif (( resume )); then
            declare -a opts

            (( emptytree )) && opts+=( --emptytree )

            (( keep_going )) && opts+=( --keep-going )

            (( oneshot )) && opts+=( --oneshot )

            [[ -n $usepkg_exclude ]] && opts+=( --usepkg-exclude "$usepkg_exclude" )

            (( no_quiet_build )) && opts+=( --quiet-build=n )

            t_emerge "--resume" "${opts[@]}"

            emerge --depclean
        elif (( update )); then
            t_emerge --deep --newuse --update --with-bdeps=y "@world"

            emerge --depclean --with-bdeps=y
        else
            declare -a opts

            (( emptytree )) && opts+=( --emptytree )

            (( keep_going )) && opts+=( --keep-going )

            (( oneshot )) && opts+=( --oneshot )

            [[ -n $usepkg_exclude ]] && opts+=( --usepkg-exclude "$usepkg_exclude" )

            (( no_quiet_build )) && opts+=( --quiet-build=n )

            read -ra PKG_ARR <<< "$packages"

            t_emerge "${opts[@]}" "${PKG_ARR[@]}"

            emerge --depclean
        fi
        ;;
    *)
        exit 1
        ;;
esac
