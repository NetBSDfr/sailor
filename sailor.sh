#!/bin/sh

include=include

usage()
{
	echo "usage: $0 build <ship.conf>"
	echo "       $0 start <ship.conf>"
	echo "       $0 stop <ship id>"
	echo "       $0 status <ship id>"
	echo "       $0 destroy <ship.conf>"
	echo "       $0 run <ship id> <command> ..."
	echo "       $0 enter <ship id> [user]"
	echo "       $0 rcd <package>"
	echo "       $0 ls"
	exit 1
}

[ $# -lt 1 ] && usage

cmd=${1}
param=${2}

. ${include}/define.sh

prefix=$([ -n "$LOCALBASE" ] && echo $LOCALBASE || ${pkg_info} -QLOCALBASE pkgin)
PATH=${PATH}:${prefix}/bin:${prefix}/sbin

. ${include}/platform.sh
. ${include}/deps.sh
. ${include}/helpers.sh

if [ "$(${id} -u)" != "0" ]; then
	echo "please run $0 with UID 0"
	exit 1
fi

reqs=""
libs=""
varbase=$(${pkg_info} -QVARBASE pkgin)
varrun="${varbase}/run/sailor"
sysconfdir=$(${pkg_info} -QPKG_SYSCONFDIR pkgin)
globships=${sysconfdir}/sailor/ships

: ${varbase:=/var}
: ${sysconfdir:=${prefix}/etc}

[ ! -d "${varrun}" ] && ${mkdir} ${varrun}

# system path for ships configuration files
_param=${globships}/${param}

# ship parameter is a path
if [ -e "${param}" ]; then
	param="$(dirname ${param})/$(basename ${param})"
	# parameter is a file, source it
	[ -f ${param} ] && . ${param}
# try if ship configuration is a global system path
elif [ -f ${_param} ]; then
	. ${_param}
	param=${_param}
fi

has_services()
{
	[ -z "${services}" ] && return 1 || return 0
}

build()
{
	# 1. ship directory does not exist
	# 2. ship directory exists but is empty (i.e. mount point)
	[ -z "$(ls -A ${shippath} 2>/dev/null)" ] && \
		${mkdir} -p ${shippath} || \
		exit 1

	# copy binaries and dependencies from host
	for bin in ${def_bins} ${shipbins}
	do
		bin_requires ${bin}
	done
	# copy flat files from host
	for file in ${def_files}
	do
		${pax} ${file} ${shippath}
	done

	# devices
	for d in dev etc/rc.d
	do
		${mkdir} -p ${shippath}/${d}
	done
	mkdevs

	# needed for pkg_install / pkgin to work
	for d in db/pkg db/pkgin log run tmp
	do
		${mkdir} ${shippath}/${varbase}/${d}
	done

	# tmp directory
	${mkdir} ${shippath}/tmp
	chmod 1777 ${shippath}/tmp ${shippath}/var/tmp

	# synchronize optional directory
	[ -n "$sync_dirs" ] && for d in $sync_dirs; do
			${pax} ${d} ${shippath}
		done

	# setup TLS certificates, see https://wiki.netbsd.org/certctl-transition/
	# assume /usr/share/certs and /usr/share/examples/certctl/certs.conf sync
	chroot ${shippath} certctl rehash
	# raw pkg_install / pkgin installation
	pkg_requires pkg_install
	for p in pkg_install pkgin
	do
		${pkg_tarup} -d ${shippath}/tmp ${p}
		${tar} zxfp ${shippath}/tmp/${p}*tgz -C ${shippath}/${prefix}
	done
	bin_requires ${prefix}/sbin/pkg_add
	bin_requires ${prefix}/bin/pkgin
	# install pkg{_install,in} the right way
	chroot ${shippath} ${prefix}/sbin/pkg_add \
		/tmp/pkg_install*
	
	# minimal etc provisioning
	${mkdir} -p ${shippath}/etc
	[ ! -f ${shippath}/etc/localtime ] && \
		${cp} /usr/share/zoneinfo/GMT ${shippath}/etc/localtime
	[ ! -f ${shippath}/etc/resolv.conf ] && \
		${cp} /etc/resolv.conf ${shippath}/etc/
	# custom DNS (mDNSresponder for OS X)
	dns add
	# custom /etc
	common="ships/common"
	# populate commons
	for t in all ${OS}
	do
		[ -d ${common}/${t} ] && ${rsync} ${common}/${t}/ ${shippath}/
	done
	# populate 3rd party
	[ -d ships/${shipname} ] && ${rsync} ships/${shipname}/ ${shippath}/

	# ${prefix} changes depending on the OS, configurations to be copied
	# to ship's ${prefix} are located in ships/${shipname}/PREFIX and
	# then copied to ${shippath}/PREFIX. The following will move them to
	# the correct ${prefix}
	[ -d ${shippath}/PREFIX ] && \
		${rsync} ${shippath}/PREFIX/ ${shippath}/${prefix}/
	# fix etc perms
	${chown} -R root:wheel ${shippath}/etc
	ship_master_passwd=${shippath}/etc/${master_passwd}
	[ -f ${ship_master_passwd} ] && ${chmod} 600 ${ship_master_passwd}

	need_tools pkgin

	pkg_reqs_done=""
	# install pkgin dependencies REQUIRES / libraries
	get_pkg_deps pkgin

	# reinstall pkgin properly
	${pkgin} -y -c ${shippath} in pkgin

	${pkgin} -y -c ${shippath} update

	for pkg in ${packages}
	do
		get_pkg_deps ${pkg}
	done

	# mounts might be needed at build for software installation
	mounts mount

	if [ -n "${packages}" ]; then
		PKG_RCD_SCRIPTS=yes ${pkgin} -y -c ${shippath} in ${packages}
		${pkgin} -y clean
	fi

	has_services && for s in ${services}
	do
		echo "${s}=YES" >> ${shippath}/etc/rc.conf
	done
	shipid=`${od} -A n -t x -N 8 /dev/urandom|${tr} -d ' '`
	echo ${shipid} > ${shippath}/shipid
}

ipupdown()
{
	[ "${1}" = "up" ] && action="alias" || action="-alias"

	for iface in $(iflist)
	do
		eval address=\$ip_${iface}
		[ -n "${address}" ]  && break
	done
	[ -z "${iface}" -o -z "${address}" ] && return

	${ifconfig} ${iface} ${address} ${action}
}

has_shipid()
{
	[ -f ${shippath}/shipid ] && return 0 || return 1
}

has_shipidfile()
{
	if [ ! -f ${shipidfile} ]; then
		echo "ship ${shipid} is not running"
		exit 1
	fi
	. ${shipidfile}
}

provide_conf_file()
{
	if [ ! -f "${1}" ]; then
		echo "please provide ship configuration file"
		exit 1
	fi
}

get_shipid()
{
	has_shipid && ${cat} ${shippath}/shipid
}

at_cmd_run()
{
	[ ! -d ${shippath} ] && return
	cmd=${1}; file=${2}
	${grep} "^run_at_${cmd}" ${file}|while read line
	do
		eval ${line}
		eval chroot ${shippath} ${sh} -c \"\$run_at_${cmd}\"
	done
}

sh_cmd_run()
{
	chroot ${shippath} $@
}

rc_d_name()
{
	pkgurl=$(${pkgin} pkg-build-defs ${1} | \
		${grep} -oE "(ft|ht)tps?://[^:]+t[bg]z")
	[ -z "${pkgurl}" ] && exit 1
	pkgname=${pkgurl##*/}
	tempdir=$(mktemp -d /tmp/_sailor.XXXXX)
	cd ${tempdir}
	${curl} -s -o ${pkgname} "${pkgurl}"
	if ! file -b ${pkgname}|${grep} gzip >/dev/null 2>&1; then
		# ar does not support stdin as argument
		ar x ${pkgname}
		pkgext=${pkgname##*.}
		pkgname=${pkgname%*.tgz}.tmp.${pkgext}
	fi
	for rcd in $(${tar} zxvf ${pkgname} 2>&1|${grep} -oE '[^\ \t]+/rc.d/.+')
	do
		eval $(${grep} '^name=' ${rcd})
		[ ! -z "${name}" ] && \
			echo "likely name for service: ${name}"
	done
	rm -rf ${tempdir}
}

rc_d_cmd()
{
	cmd=${1}

	has_services && for s in ${services}
	do
		if ! chroot ${shippath} /etc/rc.d/${s} ${cmd}; then
			echo "error while chrooting to ${shippath}"
		fi
	done
}

case ${cmd} in
rcd|ls)
	# no ship id / conf file needed
	;;
*)
	shipidfile=""
	# parameter is a directory, probably a shippath
	if [ -d ${param} ]; then
		shippath=${param}
	# must be a shipid then
	elif [ ! -f ${param} ]; then
		shipidfile=${varrun}/${param}.ship
		if [ ! -f ${shipidfile} ]; then
			echo "\"${param}\": invalid id or file"
			exit 1
		fi
		. ${shipidfile}
	fi

	# no shipid recorded yet, have we got one in shippath?
	[ -z ${shipid} ] && has_shipid && shipid=$(get_shipid)
	# shipid exists, build a shipfileid path
	[ -n "${shipid}" -a -z "${shipidfile}" ] && \
		shipidfile="${varrun}/${shipid}.ship"
	;;
esac

case ${cmd} in
build|create|make)
	if [ -z "${shippath}" -o "${shippath}" = "/" ]; then
		echo "ABORTING: \"\$shippath\" set to \"$shippath\""
		exit 1
	fi
	if [ -n "${shipid}" ]; then
		echo "ship already exists with id ${shipid}"
		exit 1
	fi

	build

	# run user commands after the jail is built
	at_cmd_run build ${param}
	# umount devfs and loopback mounts
	mounts umount
	# remove mDNS (OS X)
	dns del
	;;
destroy)
	provide_conf_file ${param}
	if [ -z "${shipid}" ]; then
		echo "ship does not exist or is incomplete"
		exit 1
	fi
	if [ -f ${shipidfile} ]; then
		echo "ship is running with id ${shipid}, not destroying"
		exit 1
	fi
	printf "really delete ship ${shippath}? [y/N] "
	read reply
	case ${reply} in
	y|yes)
		# run user commands before removing data
		at_cmd_run destroy ${param}
		# delete the ship
		[ "${shippath}" != "/" ] && ${rm} -rf ${shippath}
		;;
	*)
		exit 0
		;;
	esac
	;;
start|stop|status)
	if [ "${cmd}" != "start" -a -z "${shipid}" ]; then
		echo "please use ship id ${shipid}"
		exit 1
	fi

	case ${cmd} in
	start)
		provide_conf_file ${param}
		if [ -n "${shipidfile}" -a -f "${shipidfile}" ]; then
			echo "ship ${shipid} is already started"
			exit 1
		fi
		if [ -z "${shipid}" ]; then
			echo "nonexistent ship"
			exit 1
		fi
		echo "shipid=${shipid}" > ${shipidfile}
		echo "conf=${param}" >> ${shipidfile}
		echo "starttime=$(date +%s)" >> ${shipidfile}
		${cat} ${param} >> ${shipidfile}
		# start user commands after the service is started
		ipupdown up
		# add mDNS entry (OS X)
		dns add
		# mount loopbacks and devfs
		mounts mount
		# execute rc.d scripts if any
		rc_d_cmd ${cmd}
		# start custom run_at_start commands
		at_cmd_run start ${param}
		echo "ship id: ${shipid}"
		;;
	stop)
		has_shipidfile
		# execute rc.d scripts if any
		rc_d_cmd ${cmd}
		# shutdown ip aliases if any
		ipupdown down
		# start user commands after the service is stopped
		at_cmd_run stop ${shipidfile}
		# remove mDNS entry (OS X)
		dns del
		# umount loopbacks and devfs
		mounts umount
		${rm} ${shipidfile}
		;;
	status)
		has_shipidfile
		# execute rc.d scripts if any
		rc_d_cmd ${cmd}
		at_cmd_run status ${shipidfile}
		;;
	esac
	;;
ls)
	format="%-${col1}s | %-${col2}s | %-${col3}s | %-${col4}s\n"
	printf "${format}" "ID" "name" "configuration file" "uptime"
	printf "%${cols}s\n"|tr ' ' '-'
	now=$(date +%s)
	for f in ${varrun}/*.ship
	do
		[ ! -f "${f}" ] && exit 0
		. ${f}
		. ${conf}
		up=$(epoch_to_hms $((${now} - ${starttime})))
		conf=$(basename ${conf})
		printf "${format}" "${shipid}" "${shipname}" "${conf}" "${up}"
	done
	;;
rcd)
	rc_d_name ${param}
	;;
run)
	shift; shift # remove command and ship id
	sh_cmd_run $@
	;;
enter)
	has_shipidfile
	[ $# -gt 2 ] && suser="sudo -u ${3}"
	chroot ${shippath} ${suser} ${sh}
	;;
*)
	usage
	;;
esac

exit 0
