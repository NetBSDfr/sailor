# platform specific variables and functions

# needed 3rd party programs
for bin in pkg_info pkg_tarup pkgin rsync curl
do
	binpath=$(command -v ${bin})
	if [ -z "${binpath}" ]; then
		echo "${bin} is required for sailor to work (probably not in \$PATH)"
		exit 1
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
	# dyld is OS X's dynamic loader
	# /System/Library/Frameworks* are needed by dscl which is needed by
	# useradd / groupadd wrappers
	SLF="/System/Library/Frameworks"
	def_bins="/usr/lib/dyld /usr/bin/dscl /usr/bin/cut /usr/bin/which \
	${SLF}/Foundation.framework/Versions/C/Foundation \
	${SLF}/DirectoryService.framework/Versions/A/DirectoryService \
	${SLF}/CoreFoundation.framework/Versions/A/CoreFoundation"
	# request-schema.plist needed for dscl
	def_files="/System/Library/OpenDirectory/request-schema.plist"
	debug_bins="$(which dtruss) $(which dtrace) $(which cp) $(which ls) \
		$(which cat) $(which expr) $(which bash) $(which less) \
		$(which otool)"
	;;
NetBSD)
	p_ldd() {
		/usr/bin/ldd -f'%p\n' ${1}
	}
	mkdevs() {
		${cp} /dev/MAKEDEV ${shippath}/etc
		chroot ${shippath} sh -c "cd /dev && /etc/MAKEDEV -M std"
	}
	mounts() {
		mcmd=${1}
		# mount / umounts ro and ro mountpoints declared in
		# ship configuration file
		for mtype in ro rw
		do
			eval mnt=\$"${mtype}_mounts"
			[ -z "${mnt}" ] && continue
			for mp in ${mnt}
			do
				[ ! -d "${mp}" ] && continue
				${mkdir} ${shippath}/${mp}
				[ "${mcmd}" = "mount" ] && \
					${loopmount} -o ${mtype} \
					${mp} ${shippath}/${mp}
				[ "${mcmd}" = "umount" ] && \
					${umount} ${shippath}/${mp}
			done
		done
		# umount devfs / tmpfs
		[ "${mcmd}" = "umount" ] && \
			${mount}|grep -q ${shippath}/dev && \
			${umount} ${shippath}/dev
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
	for s in $(awk '/^[^#].+\.so/ {print $3}' /etc/pam.d/su)
	do
		def_bins="$def_bins /usr/lib/security/${s}*"
	done
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
	 /bin/sh ${ping} /sbin/mknod /sbin/mount_tmpfs /sbin/mount_mfs \
	 /bin/cat /bin/ln /bin/chmod"
