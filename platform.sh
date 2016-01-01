pkgin=`which pkgin`
pax="${debug}`which pax` -rwpe"
rsync="${debug}`which rsync` -av"
cp=`${debug}which cp`
pkg_info=`which pkg_info`
awk=`which awk`
sort=`which sort`
grep=`which egrep`
tar=`which tar`
OS=`uname -s`

# pkg_install additional tools
useradd=`which useradd`
groupadd=`which groupadd`

case $OS in
*arwin*)
	ldd=`which otool`
	;;
NetBSD)
	ldd=`which ldd`
	def_bins="/libexec/ld.elf_so /usr/libexec/ld.elf_so"
	;;
esac

# binaries needed by pkg_install and not listed in +INSTALL
def_bins="${def_bins} /usr/sbin/pwd_mkdb ${useradd} ${groupadd} \
	${pkg_info} ${pkgin} /bin/sh /bin/test /sbin/nologin /bin/echo \
	/bin/ps /bin/sleep `which sysctl`"
