cat=`which cat`
pkgin=`which pkgin`
pax="${debug}`which pax` -rwpe"
rsync="${debug}`which rsync` -av"
cp=`${debug}which cp`
chown=`which chown`
chmod=`which chmod`
pkg_info=`which pkg_info`
awk=`which awk`
sort=`which sort`
grep=`which egrep`
tar=`which tar`
mkdir="`which mkdir` -p"
touch=`which touch`
rm="`which rm` -f"
ls=`which ls`
od=`which od`
tr=`which tr`
readlink=`which readlink`
umount=`which umount`
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
	loopmount="/sbin/mount -t null"
	;;
esac

# binaries needed by many packages and not listed in +INSTALL
def_bins="${def_bins} /usr/sbin/pwd_mkdb ${useradd} ${groupadd} \
	${pkg_info} ${pkgin} /bin/sh /bin/test /sbin/nologin /bin/echo \
	/bin/ps /bin/sleep `which sysctl`"
