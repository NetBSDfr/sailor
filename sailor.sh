#!/bin/sh

[ $# -lt 1 ] && echo "usage: $0 <ship.conf>" && exit 1

. ${1}

pkgin=`which pkgin`
pax="`which pax` -rwpe"
rsync="`which rsync` -av"
pkg_info=`which pkg_info`
awk=`which awk`
sort=`which sort`
sed=`which sed`

[ ! -d ${shippath} ] && mkdir -p ${shippath}

reqs=""

link_target()
{
	for lib in ${reqs}
	do
		[ -h ${lib} ] && reqs="${reqs} `readlink -f ${lib}`"
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
	reqs=`ldd -f'%p\n' ${1}`

	[ ! -z "${reqs}" ] && sync_reqs ${1}
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
def_bins="${prefix}/bin/pkgin ${prefix}/sbin/pkg_info \
	/libexec/ld.elf_so /usr/libexec/ld.elf_so \
	/usr/sbin/pwd_mkdb"
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
for d in db/pkg db/pkgin log run
do
	mkdir -p ${shippath}/${varbase}/${d}
done

${pax} ${prefix}/etc/pkgin ${shippath}/

# raw pkg_install / pkgin installation
pkg_requires pkg_install
for p in pkg_install pkgin
do
	pkg_tarup -d ${shippath}/tmp ${p}
	tar zxfp ${shippath}/tmp/${p}*tgz -C ${shippath}/${prefix}
	# install pkg{_install,in} the right way
done
chroot ${shippath} ${prefix}/sbin/pkg_add /tmp/pkg_install*tgz

# minimal etc provisioning
mkdir -p ${shippath}/etc
cp /usr/share/zoneinfo/GMT ${shippath}/etc/localtime
cp /etc/resolv.conf ${shippath}/etc/
${rsync} etc/ ${shippath}/etc/
# populate 3rd party
${rsync} ships/${shipname}/ ${shippath}/

${pkgin} -y -c ${shippath} update

#touch ${shippath}/etc/master.passwd /etc/pwd.db
#chroot ${shippath} /usr/sbin/pwd_mkdb /etc/passwd

# extract needed tools from pkg_add install script
tools="`${pkg_info} -i pkgin | \
	${awk} -F= '/^[^\=]+="\// {print $2}' | \
	${sed} -E 's/[\"\ \t]//g' | ${sort} -u`"

for t in ${tools}
do
	[ -f ${t} -a -x ${t} ] && bin_requires ${t}
done

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
	${pkgin} -y -c ${shippath} install ${pkg}
done

echo "${service}=YES" >> ${shippath}/etc/rc.conf
