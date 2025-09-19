set -e

TIMEOUT=19800

source /mnt/variables.sh

LONG_OPTS=packages:,emptytree,keep-going,oneshot,usepkg-exclude:,no-quiet-build,keepwork,pgo-generate,pgo-use,no-pgo-update-check,update,resume,deselect,sync,bootstrap:,portage-profile:,emerge-perl,no-timeout

eval set -- "$(getopt --longoptions "$LONG_OPTS" --name "$0" --options "" -- "$@")" || exit 1

packages=""

emptytree=0

keep_going=0

oneshot=0

usepkg_exclude=""

no_quiet_build=0

keepwork=0

pgo_generate=0

pgo_use=0

no_pgo_update_check=0

update=0

resume=0

deselect=0

sync_flag=0

bootstrap=0

portage_profile=""

emerge_perl=0

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
        --pgo-generate)
            pgo_generate=1

            shift
            ;;
        --pgo-use)
            pgo_use=1

            shift
            ;;
        --no-pgo-update-check)
            no_pgo_update_check=1

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
        --emerge-perl)
            emerge_perl=1

            shift
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
    printf '%s\n' "$2" > "$1"
}

has_src_update() {
    local emerge

    if ! emerge=$(emerge --pretend --quiet --update --verbose $1 2>/dev/null); then
        return 2
    fi

    if grep --extended-regexp --quiet '^\[ebuild\s+N\s+\]' <<<"${emerge}"; then
        return 0
    else
        return 1
    fi
}

case $bootstrap in
    1)
        emerge-webrsync

        locale-gen --quiet

        eselect --brief locale set 6

        if [[ -n $portage_profile ]]; then
            eselect --brief profile set "$portage_profile"
        fi

        write_file /etc/portage/package.use/bootstrap "*/* -pgo"

        emerge --buildpkg=n dev-vcs/git

        emerge --sync

        if (( emerge_perl )); then
            emerge --buildpkg=n --oneshot dev-lang/perl
        fi

        t_emerge --buildpkg=n --emptytree "@system"

        rm -f /etc/portage/package.use/bootstrap
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

            if (( pgo_generate )) && (( ${#PKG_ARR[@]} == 1 )); then
                if (( no_pgo_update_check )) || (( has_src_update "${PKG_ARR[@]}" )); then
                    echo -e "CFLAGS=\"\${CFLAGS} -fprofile-generate=/var/tmp/pgo\"\nCXXFLAGS=\"\${CXXFLAGS} -fprofile-generate=/var/tmp/pgo\"" > /etc/portage/env/pgo.conf

                    echo "${PKG_ARR[*]} pgo.conf" >> /etc/portage/package.env/pgo

                    opts+=( --buildpkg=n)
                else
                    exit 1
                fi
            else
                exit 1
            fi

            pgo_used=0

            if (( pgo_use )) && (( ${#PKG_ARR[@]} == 1 )); then
                if (( no_pgo_update_check )) || (( has_src_update "${PKG_ARR[@]}" )); then
                    echo -e "CFLAGS=\"\${CFLAGS} -fprofile-use=/var/tmp/pgo\"\nCXXFLAGS=\"\${CXXFLAGS} -fprofile-use=/var/tmp/pgo\"" > /etc/portage/env/pgo.conf

                    unset "opts[-1]"

                    pgo_used=1
                else
                    exit 1
                fi
            else
                exit 1
            fi

            t_emerge "${opts[@]}" "${PKG_ARR[@]}"

            (( pgo_used )) && rm --force --recursive /etc/portage/env/pgo.conf /etc/portage/package.env/pgo /var/tmp/pgo

            emerge --depclean
        fi
        ;;
    *)
        exit 1
        ;;
esac
