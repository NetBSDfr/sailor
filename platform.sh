cat=`which cat`
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
OS=`uname -s`

# pkg_install additional tools
useradd=`which useradd`
groupadd=`which groupadd`

# needed 3rd party programs
for bin in pkg_info pkg_tarup pkgin rsync
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
	p_ldd() {
		/usr/bin/otool -L ${1}|${awk} '/\/[lL]ib.+\(/ {print $1}'
	}
	mkdevs() {
		true
	}
	mounts() {
		true
	}

	readlink=`which readlink`
	def_bins="/usr/lib/dyld /usr/bin/dscl /usr/bin/cut /usr/bin/which \
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation \
	/System/Library/Frameworks/DirectoryService.framework/Versions/A/DirectoryService \
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
	;;
NetBSD)
	p_ldd() {
		/usr/bin/ldd -f'%p\n' ${1}
	}
	mkdevs() {
		${cp} /dev/MAKEDEV ${shippath}/dev
		cd ${shippath}/dev && sh MAKEDEV std
		cd -
	}
	mounts() {
		mcmd=${1}
		for mtype in ro rw
		do
			eval mnt=\$"${mtype}_mounts"
			if [ ! -z "${mnt}" ]; then
				for mp in ${mnt}
				do
					if [ ! -z "${mp}" ]; then
						${mkdir} ${shippath}/${mp}
						[ ${mcmd} = "mount" ] && \
							${loopmount} -o ${mtype} \
								${mp} ${shippath}/${mp}
						[ ${mcmd} = "umount" ] && \
							${umount} ${shippath}/${mp}
					fi
				done
			fi
		done
	}

	readlink="`which readlink` -f"
	def_bins="/libexec/ld.elf_so /usr/libexec/ld.elf_so"
	loopmount="/sbin/mount -t null"
	;;
esac

# binaries needed by many packages and not listed in +INSTALL
def_bins="${def_bins} /usr/sbin/pwd_mkdb ${useradd} ${groupadd} \
	${pkg_info} ${pkgin} /bin/sh /bin/test /sbin/nologin /bin/echo \
	/bin/ps /bin/sleep `which sysctl`"
