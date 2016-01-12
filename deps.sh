# functions used to discover and copy libraries required by installed tools

link_target()
{
	lnk=${1}

	if [ -h ${lnk} ]; then
		realfile=`${readlink} ${lnk}`
		if [ ! -z "${realfile}" ]; then
			reqs="${reqs} ${realfile}"
		fi
	fi
}

sync_reqs()
{
	[ -z "${reqs}" ] && return

	printf "copying requirements for ${1}.. "
	for req in ${reqs}
	do
		# add symlinks targets
		link_target ${req}
	done

	${pax} ${reqs} ${shippath}/
	echo "done"
}

all_libs() {
	for l in `p_ldd ${1}`
	do
		# library already recorded ?
		if ! echo ${libs} | ${grep} -sq ${l}; then
			libs="${libs} ${l}"
			all_libs ${l}
		fi
	done
}

bin_requires()
{
	libs=""
	reqs=""
	# grep link matches both symlinks and ELF executables ;)
	if  file ${1}|${grep} -sqE '(link|Mach)'; then
		all_libs ${1}
		reqs="${libs} ${1}"

		sync_reqs ${1}
	fi

	[ -f ${1} ] && ${pax} ${1} ${shippath}/
}

pkg_requires()
{
	reqs=""
	pkg=${1%-[0-9]*}
	targets="$(${pkgin} pbd ${pkg}|${awk} -F= '/^REQUIRES=/ { print $2 }')"
	for req in ${targets}
	do
		[ -e ${req} ] && reqs="${reqs} ${req}"
	done

	sync_reqs ${pkg}
}

# extract needed tools from pkg_add install script
need_tools()
{
	tools="`${pkg_info} -i ${1} | \
		${awk} -F= '/^[^\=]+="\// {print $2}' | \
		${grep} -oE '/[^\"\ ]+' | ${sort} -u`"
	
	for t in ${tools}
	do
		[ -f ${t} -a -x ${t} ] && bin_requires ${t}
	done
}

