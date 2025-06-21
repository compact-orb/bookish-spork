set -e

TIMEOUT=19800

source /mnt/variables.sh

LONG_OPTS=packages:,emptytree,keep-going,oneshot,usepkg-exclude:,update,resume,deselect,sync,webrsync,bootstrap:,portage-profile:,emerge-perl,help

eval set -- "$(getopt --longoptions "$LONG_OPTS" -- "$@")" || exit 1

set -- $REPLY

packages=""

emptytree=0

keep_going=0

oneshot=0

usepkg_exclude=""

update=0

resume=0

deselect=0

sync_flag=0

webrsync=0

bootstrap=0

portage_profile=""

emerge_perl=0


while [[ $# -gt 0 ]]; do
    case $1 in
        --packages)
            packages+=" $2"

            emptytree=1

            shift 2
            ;;
        --emptytree)
            emptytree=1

            shift
            ;;
        --keep-going)
            keep_going=1

            emptytree=1

            shift
            ;;
        --oneshot)
            oneshot=1

            emptytree=1

            shift
            ;;
        --usepkg-exclude)
            usepkg_exclude=$2

            emptytree=1

            shift 2
            ;;
        --update)
            update=1

            emptytree=1

            shift
            ;;
        --resume)
            resume=1

            emptytree=1

            shift
            ;;
        --deselect)
            deselect=1

            emptytree=1

            shift
            ;;
        --sync)
            sync_flag=1

            emptytree=1

            shift
            ;;
        --webrsync)
            webrsync=1

            emptytree=1

            shift
            ;;
        --bootstrap)
            bootstrap=$2

            emptytree=1

            shift 2
            ;;
        --portage-profile)
            portage_profile=$2

            emptytree=1

            shift 2
            ;;
        --emerge-perl)
            emerge_perl=1

            emptytree=1

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
    timeout "$TIMEOUT" emerge "$@";
}

write_file() {
    printf '%s\n' "$2" > "$1"
}

case $bootstrap in
    1)
        emerge-webrsync --revert="$PORTAGE_SNAPSHOT_DATE" --quiet

        locale-gen --quiet

        eselect --brief locale set 6

        if [[ -n $portage_profile ]]; then
            eselect --brief profile set "$portage_profile"
        fi

        write_file /etc/portage/package.env/bootstrap  "*/* gcc.conf"

        write_file /etc/portage/package.use/bootstrap "*/* -pgo"

        emerge llvm-core/clang

        rm -f /etc/portage/package.env/bootstrap

        if (( emerge_perl )); then
            emerge --buildpkg=n --oneshot dev-lang/perl
        fi
        ;;
    2)
        if (( resume )); then
            t_emerge --buildpkg=n --emptytree --resume
        else
            t_emerge --buildpkg=n --emptytree "@system"
        fi

        rm -f /etc/portage/package.use/bootstrap
        ;;
    3)
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
        elif (( webrsync )); then
            emerge-webrsync --revert="$PORTAGE_SNAPSHOT_DATE" --quiet
        elif (( deselect )); then
            read -ra PKG_ARR <<< "$packages"

            emerge --deselect "${PKG_ARR[@]}"
        elif (( resume )); then
            t_emerge --resume

            emerge --depclean
        elif (( update )); then
            t_emerge --deep --newuse --update "@world"

            emerge --depclean
        else
            declare -a opts

            (( emptytree )) && opts+=( --emptytree )

            (( keep_going )) && opts+=( --keep-going )

            (( oneshot )) && opts+=( --oneshot )

            [[ -n $usepkg_exclude ]] && opts+=( --usepkg-exclude "$usepkg_exclude" )

            read -ra PKG_ARR <<< "$packages"

            t_emerge "${opts[@]}" "${PKG_ARR[@]}"

            emerge --depclean
        fi
        ;;
    *)
        exit 1
        ;;
esac
