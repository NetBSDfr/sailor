# platform specific variables and functions

. ${include}/helpers.sh

# needed 3rd party programs
for bin in pkg_info pkg_tarup pkgin rsync curl
do
	[ -f /etc/profile ] && . /etc/profile

	binpath="$(which ${bin})"
	if [ -z "${binpath}" ]; then
		echo "${bin} is required for sailor to work"
		if confirm "Would you like to install ${bin}? [y/N] " "${bin} is required for sailor to work" "Please answer y or N " ; then
			case ${bin} in
				pkg_info|pkgin)
					. ${include}/install_deps.sh
					test_if_pkgin_is_installed
					;;
				*)
					. ${include}/install_deps.sh
					install_3rd_party_pkg "${bin}"
			esac
		fi
	fi
	eval ${bin}=${binpath}
done

rsync="${rsync} -av"

case $OS in
Darwin)
	. ${include}/mdns.sh

	p_ldd() {
		/usr/bin/otool -L ${1}|${awk} '/\/[lL]ib.+\(/ {print $1}'
	}
	mkdevs() {
		true
	}
	mounts() {
		mcmd=${1}

		case ${mcmd} in
		mount)
			${mount} -t devfs devfs ${shippath}/dev
			;;
		umount)
			wait_umount dev
			;;
		esac
	}
	iflist() {
		${ifconfig} -l
	}
	dns() {
		mdns ${1}
	}

	readlink=$(which readlink)
	master_passwd=master.passwd
	# dyld is OSX's dynamic loader
	# /System/Library/Frameworks* are needed by dscl which is needed by
	# useradd / groupadd wrappers
	SLF="/System/Library/Frameworks"
	def_bins="/usr/lib/dyld /usr/bin/dscl /usr/bin/cut /usr/bin/which \
	${SLF}/Foundation.framework/Versions/C/Foundation \
	${SLF}/DirectoryService.framework/Versions/A/DirectoryService \
	${SLF}/CoreFoundation.framework/Versions/A/CoreFoundation"
	# request-schema.plist needed for dscl
	def_files="/System/Library/OpenDirectory/request-schema.plist"
	;;
NetBSD)
	p_ldd() {
		/usr/bin/ldd -f'%p\n' ${1}
	}
	mkdevs() {
		${cp} /dev/MAKEDEV ${shippath}/dev
		cd ${shippath}/dev && sh MAKEDEV std random
		cd -
	}
	mounts() {
		mcmd=${1}
		for mtype in ro rw
		do
			eval mnt=\$"${mtype}_mounts"
			[ -z "${mnt}" ] && continue
			for mp in ${mnt}
			do
				[ ! -d "${mp}" ] && continue
				${mkdir} ${shippath}/${mp}
				[ ${mcmd} = "mount" ] && \
					${loopmount} -o ${mtype} \
					${mp} ${shippath}/${mp}
				[ ${mcmd} = "umount" ] && \
					${umount} ${shippath}/${mp}
			done
		done
	}
	iflist() {
		${ifconfig} -l
	}
	dns() {
		true
	}

	readlink="$(which readlink) -f"
	master_passwd=master.passwd
	def_bins="/libexec/ld.elf_so /usr/libexec/ld.elf_so $(which pwd_mkdb)"
	loopmount="/sbin/mount -t null"
	;;
Linux)
	# Linux is on the works right now
	p_ldd() {
		/usr/bin/ldd ${1}|${grep} -oE '[^[:space:]]*/lib[^[:space:]]+'
	}
	mkdevs() {
		true
	}
	mounts() {
		mcmd=${1}

		for m in run dev proc sys
		do
			case ${mcmd} in
			mount)
				${mkdir} ${shippath}/${m}
				mount --bind /${m} ${shippath}/${m}
				;;
			umount)
				wait_umount ${m}
				;;
			esac
		done
	}
	iflist() {
		ls -1 /sys/class/net|xargs
	}
	dns() {
		true
	}

	readlink="$(which readlink) -f"
	master_passwd=shadow
	def_bins="/lib/ld-linux.so.2 /lib64/ld-linux-x86-64.so.2 \
		/lib64/libresolv.so.2 /lib64/libnss_dns.so.2 \
		/lib64/libnss_files.so.2"
	;;
esac

# binaries needed by many packages and not listed in +INSTALL
# most installation and startup scripts also need /bin/sh
def_bins="${def_bins} ${useradd} ${groupadd} ${pkg_info} ${pkgin} \
	/bin/sh /bin/test $(which nologin) /bin/echo /bin/ps /bin/sleep \
	$(which sysctl) $(which logger) $(which kill) $(which printf) \
	 /bin/sh ${ping}"
