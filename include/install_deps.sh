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
		os="linux"
	elif echo "$OS" | grep -q "[Dd]arwin" ; then
		os="osx"
	else
		printf "System not yet supported, sorry.\n"
		exit 1
	fi

	curl="${curl} --silent --max-time 3 --connect-timeout 2"
	egrep="${egrep} -o"

	bootstrap_install_url="https://pkgsrc.joyent.com/install-on-$os/"
	bootstrap_doc="/tmp/pkgin_install.txt"
	${curl} -o ${bootstrap_doc} ${bootstrap_install_url}
	bootstrap_url="$(${cat} ${bootstrap_doc} | ${egrep} -A1 "Download.*bootstrap" | ${egrep} "curl.*$ARCH.*")"

	read bootstrap_hash bootstrap_tar <<EOF
$(${cat} ${bootstrap_doc} | ${egrep} "[0-9a-z]{32}.+$ARCH.tar.gz")
EOF

	fetch_localbase="$(${curl} ${bootstrap_url#curl -Os} | ${tar} ztvf - | ${egrep} '/.+/pkg_install.conf$')"
	pkgin_localbase="${fetch_localbase%/*/*}"
	pkgin_localbase_bin="$pkgin_localbase/bin"
	pkgin_localbase_sbin="$pkgin_localbase/sbin"
	pkgin_localbase_man="$pkgin_localbase/man"
	pkgin_bin="$pkgin_localbase_bin/pkgin"

	export PATH=$pkgin_localbase_sbin:$pkgin_localbase_bin:$path
	# Need to run some test if it's really necessary.
	export MANPATH=$pkgin_localbase_man:$manpath

	if echo "$OS" | ${grep} -q "[Dd]arwin" ; then

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
	fi

	# Generic variables and commands.
	bootstrap_tmp="/tmp/${bootstrap_tar}"
	# Joyent PGPkey
	repo_gpgkey="0xDE817B8E"

	# download bootstrap kit.
	${curl} -o "${bootstrap_tmp}" "${bootstrap_url#curl -Os}"
	if [ "$?" != 0 ]; then
		printf "version of bootstrap for $os not found.\nplease install it by yourself.\n"
		exit 1
	fi

	# Verify SHA1 checksum of the bootstrap kit.
	echo "$bootstrap_sha $bootstrap_path" | ${shasum} -a 256 -c - || exit 1

	# install bootstrap kit to the right path regarding your distribution.
	${tar} xfp "$bootstrap_path" -c / >/dev/null 2>&1

	# If GPG available, verify GPG signature.
	if [ ! -z ${gpg} ]; then
		# Verifiy PGP signature.
		${gpg} --keyserver hkp://keys.gnupg.net --recv-keys $repo_gpgkey >/dev/null 2>&1
		${curl} -s -o "${bootstrap_path}.asc ${bootstrap_url}/${bootstrap_tar}.asc"
		${gpg} --verify "${bootstrap_path}.asc" >/dev/null 2>&1
	fi

	# Fetch packages.
	${rm} -r -- "$PKGIN_VARDB" "$bootstrap_tmp" "$bootstrap_doc"
	"$pkgin_bin" -y update
}

test_if_pkgin_is_installed()
{

	if [ -z ${pkgin} ]; then
		install_pkgin
	fi

	return 0
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
