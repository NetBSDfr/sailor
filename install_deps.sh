#! /usr/bin/env sh

. ./define.sh

sanity_check()
{
    if echo "$OS" | grep -q "[Dd]arwin" ; then
        if [ -f /usr/local/bin/brew ]; then
            printf "Homebrew detected, pkgsrc can conflict with\n"
            exit 1
        fi
        if [ -f /usr/local/bin/port ]; then
            printf "MacPorts detected, pkgsrc can conflict with\n"
            exit 1
        fi
    fi
}

install_pkgin()
{

    PKGSRC_SITE="http://pkgsrc.joyent.com/packages/$OS"
    PKGSRC_QUARTER="$(date +"%Y %m" |\
                        ${awk} '{ Q=int( $2/4 ); Y=$1
                            if ( Q == 0 ){ Q=4; Y=Y-1; }
                                printf( "%sQ%s\n", Y, Q); 
                            }')"

    BOOTSTRAP_PATH="${PKGSRC_SITE}/bootstrap/"
    
    # Maybe a case ?
    # + where to find the SHA1SUM ?!
    if [ "$OS" = "Linux" ]; then

        BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-el6-x86_64.tar.gz"
        BOOTSTRAP_SHA="493e0071508064d1d1ea32956d2ede70f3c20c32"
        PKGIN_BIN="/usr/pkg/bin/pkgin"
        export PATH=/usr/pkg/sbin:/usr/pkg/bin:$PATH
        export MANPATH=/usr/pkg/man:$MANPATH

    elif echo "$OS" | grep -q "[Dd]arwin" ; then
        PKGIN_BIN="/opt/pkg/bin/pkgin"
        export PATH=$PATH:/opt/pkg/sbin:/opt/pkg/bin

        if [ ! -f /etc/paths.d/pkgsrc ]; then
            printf "/opt/pkg/bin\n/opt/pkg/sbin\n" >> /etc/paths.d/pkgsrc
        fi
        if [ ! -f /etc/manpaths.d/pkgsrc ]; then
            printf "MANPATH /opt/pkg/man\nMANPATH /opt/pkg/share/man\n" >> /etc/manpaths.d/pkgsrc
        fi

        if [ ! $(grep "path_helper" $SHELLRC) ]; then
            printf "\n# Evaluate system PATH\nif [ -x /usr/libexec/path_helper ]; then\n\teval \"$(/usr/libexec/path_helper -s)\"\nfi\n"
        fi
        if [ -x /usr/libexec/path_helper ]; then
            eval "$(/usr/libexec/path_helper -s)"
        fi

        if [ "$ARCH" = "x86_64" ]; then
            BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-x86_64.tar.gz"
            BOOTSTRAP_SHA="c150c0db1daddb4ec49592a7563c2838760bfb8b"
        else
            BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-i386.tar.gz"
            BOOTSTRAP_SHA="5820c3674be8b1314f3a61c8d82646da34d684ac"
        fi

    else
        printf "Not supported yet.\n"
        exit 1
    fi

    # Generic variables and commands.
    BOOTSTRAP_TMP="/tmp/${BOOTSTRAP_TAR}"
    # Joyent PGPkey
    REPO_GPGKEY="0xDE817B8E"

    # Download bootstrap kit.
    if [ ! -f "$BOOTSTRAP_PATH" ]; then
        ${curl} -o "$BOOTSTRAP_PATH${BOOTSTRAP_TAR}" "${BOOTSTRAP_TMP}"
        if [ "$?" != 0 ]; then
            printf "Version of bootstrap for $OS not found.\nPlease install it by yourself.\n"
            exit 1
        fi
    fi
    
    # Verify SHA1 checksum of the bootstrap kit.
    echo "$BOOTSTRAP_SHA $BOOTSTRAP_PATH" | ${shasum} -a 256 -c - || exit 1

    # Install bootstrap kit to the right path regarding your distribution.
    ${tar} xfP "$BOOTSTRAP_PATH" -C / >/dev/null 2>&1

    # Install gpg if not available.
    if [ -z ${gpg} ]; then
        "$PKGIN_BIN" -y in gnupg
    fi

    # Verifiy PGP signature.
    ${gpg} --keyserver hkp://keys.gnupg.net --recv-keys $REPO_GPGKEY >/dev/null 2>&1
    ${curl} -s -o "${BOOTSTRAP_PATH}.asc ${BOOTSTRAP_URL}/${BOOTSTRAP_TAR}.asc"
    ${gpg} --verify "${BOOTSTRAP_PATH}.asc" >/dev/null 2>&1

    # Fetch packages.
    ${rm} -rf -- "$PKGIN_VARDB"
    "$PKGIN_PATH" -y update
}

test_if_pkgin_is_installed()
{

    if [ -z ${pkgin} ]; then
        install_pkgin
    fi
}

install_3rd_party_pkg()
{
    pkg=${1}
    test_if_pkgin_is_installed

    if [ -z ${pkg} ] ; then
        ${pkgin} search ${pkg}
        if [ "$?" != 0 ]; then
            printf "Package not found.\n"
            exit 1
        else
            ${pkgin} -y in ${pkg}
        fi
    fi
}
