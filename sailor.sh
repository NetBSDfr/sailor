#!/bin/sh

[ $# -lt 1 ] && echo "usage: $0 <ship.conf>" && exit 1

. ${1}

pkgin=`which pkgin`
pax="`which pax` -rwpe"
rsync="`which rsync` -av"
pkg_info=`which pkg_info`
awk=`which awk`
sort=`which sort`
grep=`which egrep`
tar=`which tar`
OS=`uname -s`

case $OS in
*arwin*)
	ldd=`which otool`
	;;
*BSD)
	ldd=`which ldd`
	;;
esac

[ ! -d ${shippath} ] && mkdir -p ${shippath}

reqs=""

link_target()
{
	for lnk in ${reqs}
	do
		[ -h ${lnk} ] && reqs="${reqs} `readlink -f ${lnk}`"
	done
}

sync_reqs()
{
	echo -n "copying requirements for ${1}.. "
	link_target ${reqs}

	${pax} ${reqs} ${shippath}/
	echo "done"
}

bin_requires()
{
	# grep link matches both symlinks and ELF executables ;)
	if [ ! -z "`file ${1}|${grep} 'link'`" ]; then
		reqs="`${ldd} -f'%p\n' ${1}` ${1}"
	
		[ ! -z "${reqs}" ] && sync_reqs ${1}
	fi
	${pax} ${1} ${shippath}/
}

pkg_requires()
{
	reqs=`${pkgin} pkg-build-defs ${1} | \
		awk -F= '/^REQUIRES=/ { print $2 }'`

	[ ! -z "${reqs}" ] && sync_reqs ${1}
}

# install wanted binaries
prefix=`${pkg_info} -QLOCALBASE pkgin`
varbase=`${pkg_info} -QVARBASE pkgin`
# /bin/sh is needed by pkg_install
def_bins="${prefix}/bin/pkgin ${prefix}/sbin/pkg_info /bin/sh \
	/libexec/ld.elf_so /usr/libexec/ld.elf_so \
	/usr/sbin/pwd_mkdb /usr/sbin/useradd /usr/sbin/groupadd \
	/bin/test /sbin/nologin /bin/echo /bin/ps /bin/sleep"
for bin in ${def_bins} ${shipbins}
do
	bin_requires ${bin}
done

# devices
mkdir -p ${shippath}/dev
cp /dev/MAKEDEV ${shippath}/dev
cd ${shippath}/dev && sh MAKEDEV std
cd -

# tmp directory
mkdir -p ${shippath}/tmp
chmod 1777 ${shippath}/tmp

# needed for pkg_install / pkgin to work
for d in db/pkg db/pkgin log run tmp
do
	mkdir -p ${shippath}/${varbase}/${d}
done

${pax} ${prefix}/etc/pkgin ${shippath}/

# raw pkg_install / pkgin installation
pkg_requires pkg_install
for p in pkg_install pkgin
do
	pkg_tarup -d ${shippath}/tmp ${p}
	${tar} zxfp ${shippath}/tmp/${p}*tgz -C ${shippath}/${prefix}
	# install pkg{_install,in} the right way
done
chroot ${shippath} ${prefix}/sbin/pkg_add /tmp/pkg_install*tgz

# minimal etc provisioning
mkdir -p ${shippath}/etc
cp /usr/share/zoneinfo/GMT ${shippath}/etc/localtime
cp /etc/resolv.conf ${shippath}/etc/
# custom /etc
common="ships/common/${OS}"
# populate commons
${rsync} ${common}/ ${shippath}/
# populate 3rd party
${rsync} ships/${shipname}/ ${shippath}/
# fix etc perms
${chown} -R root:wheel ${shippath}/etc
${chmod} 600 ${shippath}/etc/master.passwd

# extract needed tools from pkg_add install script
need_tools()
{
	tools="`${pkg_info} -i ${1} | \
		${awk} -F= '/^[^\=]+="\// {print $2}' | \
		${grep} -o '/[^\"\ ]+' | ${sort} -u`"
	
	for t in ${tools}
	do
		[ -f ${t} -a -x ${t} ] && bin_requires ${t}
	done
}

need_tools pkgin

${pkgin} -y -c ${shippath} update

for pkg in ${packages}
do
	# retrieve dependencies names
	pkg_reqs="`${pkgin} -P -c ${shippath} sfd ${pkg} | \
		awk '/^\t/ {print $1}'` ${pkg}"
	for p in ${pkg_reqs}
	do
		# install all dependencies requirements
		pkg_requires ${p}
	done
	PKG_RCD_SCRIPTS=yes ${pkgin} -y -c ${shippath} install ${pkg}
	${pkgin} -y clean
done

echo "${service}=YES" >> ${shippath}/etc/rc.conf
