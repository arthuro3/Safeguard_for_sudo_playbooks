#!/bin/sh
#####################################################################
#
#   preflight.sh
#
#   Quest Privilege Manager for UNIX
#   (C) Copyright Quest Software, 2011
#
#
#####################################################################

G_CD_PATH=""
G_PMPREFLIGHT=""
G_ARCH=""
G_VERBOSE=0
LOADER_PATH=LD_LIBRARY_PATH
PMPREFLIGHT=pmpreflight
G_DEFAULT_OPTS="--verbose"
G_RESPONSE=""
scriptdir=`dirname "$0"`
SCRIPTPATH=`cd "$scriptdir"; pwd -P`
serverdir="server"
agentdir="agent"
plugindir="sudo_plugin"
libdir="lib"

echo_err()
{
    echo $@ >&2
}

echo_verbose()
{
    if [ $G_VERBOSE -eq 1 ]; then
        echo $@
    fi
}

prompt_with_default()
{
    default=$1
    shift
    prompt=$@

    G_RESPONSE=""
    printf ">> ${prompt}  [ $default ]\n"
    printf ">> "
    read ans
    echo
    if [ "x${ans}" = "x" ]; then
        ans="${default}"
    fi

    G_RESPONSE="${ans}"
    return 0
}

preflight_prechecks()
{
    dirname / >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
        echo ""
        echo "The preflight.sh wrapper requires the \"dirname\" command."
        echo "To run preflight you will need to locate the appropriate "
        echo "pmpreflight binary for your architecture and run that directly."
        echo ""
        exit 1
    fi
}

guess_arch()
{
    ARCH=""
    case `uname -s` in
    "AIX")
        NUM="`uname -v``uname -r`"
        LOADER_PATH=LIBPATH
        if [ $NUM -ge 71 ]; then
            ARCH=aix71-rs6k
        elif [ $NUM -ge 61 ]; then
            if [ `oslevel -r | sed 's/-//'` -lt 610009 ]; then
                echo_err "Sorry, Privilege Manager requires an Operating System Maintenance Level of 6100-09 or higher."
                exit 1
            fi
            ARCH=aix61-rs6k
        fi
        ;;
    "Linux")
        case `uname -m` in
            aarch64)
                ARCH=linux-aarch64;
                ;;
            ia64)
                ARCH=linux-ia64;
                ;;
            s390|s390x)
                ARCH=linux-s390;
                ;;
            x86_64)
                ARCH=linux-x86_64
                ;;
            ppc64)
                ARCH=linux-ppc64
                ;;
            ppc64le)
                ARCH=linux-ppc64le
                ;;
            i?86)
                ARCH=linux-intel
                ;;
        esac
        ;;
    "Darwin")
        ARCH=macosx
        LOADER_PATH=DYLD_LIBRARY_PATH
        ;;
    "HP-UX")
        if [ `uname -m` =  "ia64" ]
        then
            ARCH=hpux11-ia64
        else
            ARCH=hpux-hppa`uname -r | cut -d. -f2`
            LOADER_PATH=SHLIB_PATH
        fi
        ;;
    "SunOS")
        if [ "`uname -p`" = "sparc" ]; then
            ARCH=solaris-sparc
        else
            ARCH=solaris-intel
        fi
        ;;
    "FreeBSD")
        case `uname -m` in
            amd64)
                ARCH=freebsd-x86_64
                ;;
        esac
        ;;
    *)
        ;;
    esac

    if [ "x${ARCH}" = "x" ]; then
        echo_err "Sorry, this system is not recognized as a supported platform."
        exit 1
    fi

    echo_verbose "Privilege Manager For Unix supported platform recognized as ${ARCH}"

    G_ARCH="${ARCH}"
}

get_options()
{
    while [ $# -gt 0 ]; do
        case $1 in
            --verbose)
                G_VERBOSE=1
                ;;
            --simple)
                G_VERBOSE=0
                G_DEFAULT_OPTS=""
                ;;
            --sudo)
                G_TYPE="${plugindir}"
                ;;
            --server)
                G_TYPE="${serverdir}"
                ;;
            --pmpolicy)
                G_TYPE="${agentdir}"
                ;;
        esac
        shift
    done
}

get_paths()
{
    script_path=${1}
    search_type=${G_TYPE}

    G_CD_PATH=`dirname ${script_path}`

    if [ -z "${search_type}" ]; then
        # default is server (if supported on this platform), otherwise plugin
        search_type=${serverdir}
        if ! [ -d "${G_CD_PATH}/${search_type}/${G_ARCH}" ]; then
            search_type=${plugindir}
        fi
    fi

    if [ "x${G_CD_PATH}" = "x" ]; then
        echo_err "Unable to obtain root path to CD"
        exit 1
    else
        if [ -d "${G_CD_PATH}/${search_type}/${G_ARCH}" ]; then
            G_ARCH_PATH="${G_CD_PATH}/${search_type}/${G_ARCH}"
            if [ -x "${G_CD_PATH}/${search_type}/${G_ARCH}/${PMPREFLIGHT}" ]; then
                G_PMPREFLIGHT="${G_CD_PATH}/${search_type}/${G_ARCH}/${PMPREFLIGHT}"
            fi
        else
            echo_err "Installation path ${G_CD_PATH}/${search_type}/${G_ARCH} is missing."
            exit 1
        fi

        if [ -x "${G_PMPREFLIGHT}" ]; then
                echo_verbose "Suitable ${PMPREFLIGHT} binary found in ${G_PMPREFLIGHT}"
        else
            echo_err "Unable to locate suitable ${PMPREFLIGHT} binary in '${G_CD_PATH}'"
            exit 1
        fi
    fi
}

run_preflight()
{
    OPTS=$@
    if [ "x${G_PMPREFLIGHT}" = "x" ]; then
        echo_err "G_PMPREFLIGHT is not defined"
        exit 1
    fi
    eval "loader_path_val=\$${LOADER_PATH}"
    eval $LOADER_PATH="${SCRIPTPATH}/${libdir}/${G_ARCH}:${loader_path_val}"
    export ${LOADER_PATH}
    ${G_PMPREFLIGHT} ${G_DEFAULT_OPTS} ${OPTS}
}


#####################################################################


preflight_prechecks
get_options $@
guess_arch
get_paths $0

#echo "G_CD_PATH = ${G_CD_PATH}"
#echo "G_PMPREFLIGHT = ${G_PMPREFLIGHT}"

run_preflight $@
res_preflight=$?
if [ $res_preflight -eq 0 ]; then
    if [ x"$G_TYPE" = "x" ]; then
        echo "Suitable packages can be found in:"
        for path in "${G_CD_PATH}/${serverdir}/${G_ARCH}" "${G_CD_PATH}/${plugindir}/${G_ARCH}" "${G_CD_PATH}/${agentdir}/${G_ARCH}"
        do
            if [ -e "$path" ]; then
                echo " $path"
            fi
        done
    else
        echo "Suitable packages can be found in $G_ARCH_PATH"
    fi
fi
exit $res_preflight
