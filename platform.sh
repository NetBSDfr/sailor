cat=`which cat`
sh=`which sh`
id=`which id`
pax="${debug}`which pax` -rwpe"
cp=`${debug}which cp`
chown=`which chown`
chmod=`which chmod`
awk=`which awk`
sort=`which sort`
grep=`which grep`
tar=`which tar`
mkdir="`which mkdir` -p"
touch=`which touch`
rm="`which rm` -f"
ls=`which ls`
od=`which od`
tr=`which tr`
umount=`which umount`
curl=`which curl`
ifconfig=`which ifconfig`
OS=`uname -s`

# pkg_install additional tools
useradd=`which useradd`
groupadd=`which groupadd`

# needed 3rd party programs
for bin in pkg_info pkg_tarup pkgin rsync curl
do
	binpath=`which ${bin}`
	if [ -z "${binpath}" ]; then
		echo "${bin} is required for sailor to work"
		exit 1
	fi
	eval ${bin}=${binpath}
done

rsync="${rsync} -av"

case $OS in
Darwin)
	. ./include/mdns.sh

	p_ldd() {
		/usr/bin/otool -L ${1}|${awk} '/\/[lL]ib.+\(/ {print $1}'
	}
	mkdevs() {
		true
	}
	mounts() {
		true
	}
	iflist() {
		${ifconfig} -l
	}
	dns() {
		action=${1}; shippath=${2}
		mdns ${action}
	}

	readlink=`which readlink`
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

	readlink="`which readlink` -f"
	def_bins="/libexec/ld.elf_so /usr/libexec/ld.elf_so"
	loopmount="/sbin/mount -t null"
	;;
esac

# binaries needed by many packages and not listed in +INSTALL
# most installation and startup scripts also need /bin/sh
def_bins="${def_bins} /usr/sbin/pwd_mkdb ${useradd} ${groupadd} \
	${pkg_info} ${pkgin} /bin/sh /bin/test /sbin/nologin /bin/echo \
	/bin/ps /bin/sleep `which sysctl` `which logger` `which kill` \
	`which printf` /bin/sh"
