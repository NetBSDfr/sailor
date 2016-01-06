# functions used to discover and copy libraries required by installed tools

link_target()
{
	for lnk in ${reqs}
	do
		[ -h ${lnk} ] && reqs="${reqs} `${readlink} ${lnk}`"
	done
}

sync_reqs()
{
	printf "copying requirements for ${1}.. "
	link_target ${reqs}

	${pax} ${reqs} ${shippath}/
	echo "done"
}

all_libs() {
	for l in `p_ldd ${1}`
	do
		if ! echo ${libs} | ${grep} -sq ${l}; then
			libs="${libs} ${l}"
			all_libs ${l}
		fi
	done
}

bin_requires()
{
	libs=""
	# grep link matches both symlinks and ELF executables ;)
	if  file ${1}|${grep} -sqE '(link|Mach)'; then
		all_libs ${1}
		reqs="${libs} ${1}"
	
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
		${grep} -oE '/[^\"\ ]+' | ${sort} -u`"
	
	for t in ${tools}
	do
		[ -f ${t} -a -x ${t} ] && bin_requires ${t}
	done
}

