#! /usr/bin/env sh

. ./define.sh

sanity_check()
{
    if echo "$OS" | grep -q "[Dd]arwin" ; then
        # Try to find a real way to define if another packages manager is installed.
        # According to their own documentation.
        if [ -f /usr/local/bin/brew ]; then
            printf "Homebrew detected, pkgsrc can conflict with\n"
            exit 1
        fi
        # According to their own documentation.
        if [ -f /opt/local/bin/port ]; then
            printf "MacPorts detected, pkgsrc can conflict with\n"
            exit 1
        fi
    fi
}

install_pkgin()
{
    if [ "$OS" = "Linux" ]; then
        PKGIN_LOCALBASE="/usr/pkg"
    elif echo "$OS" | grep -q "[Dd]arwin" ; then
        PKGIN_LOCALBASE="/opt/pkg"
    else
        printf "System not yet supported, sorry.\n"
        exit 1
    fi

    PKGSRC_SITE="http://pkgsrc.joyent.com/packages/$OS"
    PKGSRC_QUARTER="$(date +"%Y %m" |\
                        ${awk} '{ Q=int( $2/4 ); Y=$1
                            if ( Q == 0 ){ Q=4; Y=Y-1; }
                                printf( "%sQ%s\n", Y, Q ); 
                            }')"

    BOOTSTRAP_PATH="${PKGSRC_SITE}/bootstrap/"
    PKGIN_LOCALBASE_BIN="$PKGIN_LOCALBASE/bin"
    PKGIN_LOCALBASE_SBIN="$PKGIN_LOCALBASE/sbin"
    PKGIN_LOCALBASE_MAN="$PKGIN_LOCALBASE/man"
    PKGIN_BIN="$PKGIN_LOCALBASE_BIN/pkgin"

    JWP="https://pkgsrc.joyent.com/install-on-"

    # Maybe a case ?
    # + where to find the SHA1SUM ?!
    if [ "$OS" = "Linux" ]; then
        if ${curl} -s --max-time 1 --head --request GET "$JWP"linux/ | grep "200 OK" >/dev/null 2>&1; then
            ${curl} --connect-timeout 2 --max-time 3 --silent "$JWP"linux/ |
            ${egrep} -o '[0-9a-z]+{32}.+x86_64.tar.gz' |
            while read hash arch; do
                BOOTSTRAP_TAR="$arch"
                BOOTSTRAP_SHA="$hash"
            done
        else
            BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-el6-x86_64.tar.gz"
            BOOTSTRAP_SHA="493e0071508064d1d1ea32956d2ede70f3c20c32"
        fi

        export PATH=$PKGIN_LOCALBASE_SBIN:$PKGIN_LOCALBASE_BIN:$PATH
        export MANPATH=$PKGIN_LOCALBASE_MAN:$MANPATH

    elif echo "$OS" | grep -q "[Dd]arwin" ; then
        export PATH=$PATH:$PKGIN_LOCALBASE_SBIN:$PKGIN_LOCALBASE_BIN

        if [ ! -f /etc/paths.d/pkgsrc ]; then
            printf "%s\n%s\n" "$PKGIN_LOCALBASE_BIN" "$PKGIN_LOCALBASE_SBIN" >> /etc/paths.d/pkgsrc
        fi
        if [ ! -f /etc/manpaths.d/pkgsrc ]; then
            printf "MANPATH %s\nMANPATH %s/share/man\n" "$PKGIN_LOCALBASE_MAN" "$PKGIN_LOCALBASE" >> /etc/manpaths.d/pkgsrc
        fi

        if [ ! $(grep "path_helper" $SHELLRC) ]; then
            printf "\n# Evaluate system PATH\nif [ -x /usr/libexec/path_helper ]; then\n\teval \"$(/usr/libexec/path_helper -s)\"\nfi\n"
        fi
        if [ -x /usr/libexec/path_helper ]; then
            eval "$(/usr/libexec/path_helper -s)"
        fi

        if [ "$ARCH" = "x86_64" ]; then
            if ${curl} -s --max-time 1 --head --request GET "$JWP"osx/ | grep "200 OK" >/dev/null 2>&1; then
                ${curl} --connect-timeout 2 --max-time 3 --silent "$JWP"osx/ |
                ${egrep} -o '[0-9a-z]+{32}.+(i386|x86_64).tar.gz' |
                while read hash arch; do
                    BOOTSTRAP_TAR="$arch"
                    BOOTSTRAP_SHA="$hash"
                done
            else
                BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-x86_64.tar.gz"
                BOOTSTRAP_SHA="c150c0db1daddb4ec49592a7563c2838760bfb8b"
            fi
        else
            if ${curl} -s --max-time 1 --head --request GET "$JWP"osx/ | grep "200 OK" >/dev/null 2>&1; then
                ${curl} --connect-timeout 2 --max-time 3 --silent "$JWP"osx/ |
                ${egrep} -o '[0-9a-z]+{32}.+i386.tar.gz' |
                while read hash arch; do
                    BOOTSTRAP_TAR="$arch"
                    BOOTSTRAP_SHA="$hash"
                done
            else
                BOOTSTRAP_TAR="bootstrap-${PKGSRC_QUARTER}-i386.tar.gz"
                BOOTSTRAP_SHA="5820c3674be8b1314f3a61c8d82646da34d684ac"
            fi
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

    ${pkgin} search ${pkg}
        if [ "$?" != 0 ]; then
            printf "Package not found.\n"
            exit 1
        else
            ${pkgin} -y in ${pkg}
        fi
}
