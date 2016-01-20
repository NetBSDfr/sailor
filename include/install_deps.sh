#! /usr/bin/env sh

case ${OS} in
	[Dd]arwin)
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

		os="osx"

		;;

	[Ll]inux)
		os="linux"
		;;

	*)
		printf "System not yet supported, sorry.\n"
		exit 1
		;;
esac

install_pkgin()
{

	_curl="${curl} --silent --max-time 3 --connect-timeout 2"
	_egrep="${egrep} -o"

	joyent_base_url="https://pkgsrc.joyent.com/"
	bootstrap_install_url="${joyent_base_url}install-on-${os}/"
	bootstrap_doc="/tmp/pkgin_install.txt"
	${_curl} -o ${bootstrap_doc} ${bootstrap_install_url}
	bootstrap_url=$(${_egrep} "${joyent_base_url}packages/${OS}/bootstrap/.*.${ARCH}.tar.gz" ${bootstrap_doc})

	read bootstrap_hash bootstrap_tar <<-EOF
		$(${_egrep} "[0-9a-z]{32}.+${ARCH}.tar.gz" ${bootstrap_doc})
	EOF

	fetch_localbase="$(${_curl} ${bootstrap_url#curl -Os} | ${tar} ztvf - | ${_egrep} '/.+/pkg_install.conf$')"
	pkgin_localbase="${fetch_localbase%/*/*}"

	for p in bin sbin man; do
		eval pkgin_localbase_\${p}="${pkgin_localbase}/${p}"
	done
	pkgin_bin="${pkgin_localbase_bin}/pkgin"

	export PATH=${pkgin_localbase_sbin}:${pkgin_localbase_bin}:${PATH}

	[ "${OS}" = "Linux" ] && export MANPATH=${pkgin_localbase_man}:${MANPATH}

	# Generic variables and commands.
	bootstrap_tmp="/tmp/${bootstrap_tar}"

	# download bootstrap kit.
	if ! ${_curl} -o "${bootstrap_tmp}" "${bootstrap_url#curl -Os }"; then
		printf "version of bootstrap for ${OS} not found.\nplease install it by yourself.\n"
		exit 1
	fi

	# Verify SHA1 checksum of the bootstrap kit.
	bootstrap_sha="$(${shasum} -p ${bootstrap_tmp})"
	if [ ${bootstrap_hash} != ${bootstrap_sha:0:41} ]; then
		printf "SHA mismatch ! ABOOORT Cap'tain !\n"
		exit 1
	fi

	# install bootstrap kit to the right path regarding your distribution.
	${tar} xfp "${bootstrap_tmp}" -c / >/dev/null 2>&1

	# If GPG available, verify GPG signature.
	if [ ! -z ${gpg} ]; then
		# Verifiy PGP signature.
		repo_gpgkey="$(${_egrep} -m1 'gpg --recv-keys.*' ${bootstrap_doc})"
		${gpg} --keyserver hkp://keys.gnupg.net --recv-keys ${repo_gpgkey##* } >/dev/null 2>&1
		${_curl} -o "${bootstrap_tmp}.asc" "${bootstrap_url#curl -Os }.asc"
		${gpg} --verify "${bootstrap_tmp}.asc" >/dev/null 2>&1
	fi

	# Fetch packages.
	## TODO: check if variable are not empty or = '/'

	${rm} -r -- "$PKGIN_VARDB" "$bootstrap_tmp" "$bootstrap_doc"
	"${pkgin_bin}" -y update
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
