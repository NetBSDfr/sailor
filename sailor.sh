#!/bin/sh

usage()
{
	echo "usage: $0 <build|start|stop|status> <ship.conf> [debug]"
	exit 1
}

[ $# -lt 2 ] && usage

cf=${2}

[ $# -gt 2 ] && debug="`which echo` "

. ${cf}
. ./platform.sh

if [ -z "${shippath}" -o "${shippath}" = "/" ]; then
	echo "ABORTING: \"\$shippath\" set to \"$shippath\""
	exit 1
fi

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

has_services()
{
	[ -z "${services}" ] && return 1 || return 0
}

build()
{
	[ ! -d ${shippath} ] && mkdir -p ${shippath}

	# install wanted binaries
	prefix=`${pkg_info} -QLOCALBASE pkgin`
	varbase=`${pkg_info} -QVARBASE pkgin`

	for bin in ${def_bins} ${shipbins}
	do
		bin_requires ${bin}
	done
	
	# devices
	mkdir -p ${shippath}/dev
	${cp} /dev/MAKEDEV ${shippath}/dev
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
	${cp} /usr/share/zoneinfo/GMT ${shippath}/etc/localtime
	${cp} /etc/resolv.conf ${shippath}/etc/
	# custom /etc
	common="ships/common/${OS}"
	# populate commons
	${rsync} ${common}/ ${shippath}/
	# populate 3rd party
	${rsync} ships/${shipname}/ ${shippath}/
	# fix etc perms
	${chown} -R root:wheel ${shippath}/etc
	${chmod} 600 ${shippath}/etc/master.passwd
	
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

	has_services && for s in ${services}
	do
		echo "${service}=YES" >> ${shippath}/etc/rc.conf
	done
}

case ${1} in
build|create|make)
	build
	;;
start|stop|status)
	has_services && for s in ${services}
	do
		chroot ${shippath} /etc/rc.d/${s} ${1}
	done
	;;
*)
	usage
	;;
esac

exit 0
