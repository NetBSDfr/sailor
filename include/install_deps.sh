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

	NetBSD)
		install_pkgin_on_bsd
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
	strip_bootstrap_url="${bootstrap_url#curl -Os }"

	read bootstrap_hash bootstrap_tar <<-EOF
		$(${_egrep} "[0-9a-z]{32}.+${ARCH}.tar.gz" ${bootstrap_doc})
	EOF

	fetch_localbase="$(${_curl} ${strip_bootstrap_url} | ${tar} ztvf - | ${_egrep} '/.+/pkg_install.conf$')"
	pkgin_localbase="${fetch_localbase%/*/*}"

	for p in bin sbin man; do
		eval pkgin_localbase_\${p}="${pkgin_localbase}/${p}"
	done
	pkgin_bin="${pkgin_localbase_bin}/pkgin"

	# Add {man,}path
	case ${OS} in
		[Dd]arwin)
			pkgsrc_path="/etc/paths.d/pkgsrc"
			pkgsrc_manpath="/etc/manpaths.d/pkgsrc"
			path_helper="/usr/libexec/path_helper"

			if [ ! -f ${pkgsrc_path} ]; then
				printf "%s\n%s\n" "$pkgin_localbase_bin" "$pkgin_localbase_sbin" >> ${pkgsrc_path}
			fi
			if [ ! -f ${pkgsrc_manpath} ]; then
				printf "manpath %s\nmanpath %s/share/man\n" "$pkgin_localbase_man" "$pkgin_localbase" >> ${manpkgsrc_path}
			fi
			if [ ! $(${grep} "path_helper" ${SHELLRC}) ]; then
				printf "\n# Evaluate system PATH\nif [ -x /usr/libexec/path_helper ]; then\n\teval \"$(${path_helper} -s)\"\nfi\n"
			fi
			if [ -x ${path_helper} ]; then
				eval "$(${path_helper} -s)"
			fi
			;;
		[Ll]inux)
			break
			;;
	esac

	[ "${OS}" = "Linux" ] && export MANPATH=${pkgin_localbase_man}:${MANPATH}

	# Generic variables and commands.
	bootstrap_tmp="${HOME}/${bootstrap_tar}"

	# download bootstrap kit.
	if ! ${_curl} -o "${bootstrap_tmp}" "${strip_bootstrap_url}"; then
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
	if [ ! -n "${gpg}" ]; then
		# Verifiy PGP signature.
		repo_gpgkey="$(${_egrep} -m1 'gpg --recv-keys.*' ${bootstrap_doc})"
		${gpg} --keyserver hkp://keys.gnupg.net --recv-keys ${repo_gpgkey##* } >/dev/null 2>&1
		${_curl} -o "${bootstrap_tmp}.asc" "${strip_bootstrap_url}.asc"
		if ! ${gpg} --verify "${bootstrap_tmp}.asc" >/dev/null 2>&1 ; then
			while true; do
				read -p "gpg verification failed, would you still proceed? [y/N] " yN
				case ${yN} in
					[y])
						break
						;;
					[N])
						exit 1
						;;
					*)
						printf "Please answer y or N [y/N] "
						;;
				esac
			done
		fi
	fi

	for var in "$PKGIN_VARDB" "$bootstrap_tmp" "$bootstrap_doc"; do
		if [ ! -z ${var} ] && [ ${var} != "/" ] ; then
			${rm} -r -- "${var}"
		fi
	done

	# Fetch packages.
	"${pkgin_bin}" -y update
}

test_if_pkgin_is_installed()
{
	[ -z ${pkgin} ] && install_pkgin
	return 0
}

install_3rd_party_pkg()
{
	pkg=${1}
	test_if_pkgin_is_installed

	if ! ${pkgin} search ${pkg}; then
		printf "Package not found.\n"
		exit 1
	else
		${pkgin} -y in ${pkg}
	fi
}
