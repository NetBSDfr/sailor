# inspired from https://raw.githubusercontent.com/joyent/pkgbuild/master/scripts/mksandbox-osx

PB="/usr/libexec/PlistBuddy"
PLIST="/var/run/com.apple.mDNSResponder.plist"
ENTRY="Sockets:Listeners"

getent_id()
{
	sockpath=${1}; plist=${2}
	i=0
	while :
	do
		sp=$(${PB} -c "Print ${ENTRY}:${i}:SockPathName" ${plist} 2>&1)

		[ $? -ne 0 ] && break

		if [ "${sp}" = "${sockpath}/var/run/mDNSResponder" ]; then
			echo ${i}
			break
		fi
		i=$(($i + 1))
	done
}

mdns()
{
	action=${1}

	PLIST_SYSTEM="/System/Library/LaunchDaemons/com.apple.mDNSResponder.plist"
	if [ ! -f ${PLIST} ]; then
		cp ${PLIST_SYSTEM} ${PLIST}
		${DEBUG} launchctl unload ${PLIST_SYSTEM}
		${DEBUG} launchctl load -w ${PLIST}
	fi

	addlist="/tmp/add.$$.plist"
	cat >${addlist}<<-EOF
	<array>
		<dict>
			<key>SockFamily</key>
			<string>Unix</string>
			<key>SockPathName</key>
			<string>${shippath}/var/run/mDNSResponder</string>
			<key>SockPathMode</key>
			<integer>438</integer>
		</dict>
	</array>
	EOF

	case ${action} in
	add)
		# Ensure Sockets:Listeners is an array.
		${PB} -c "Print ${ENTRY}:0" ${PLIST} >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			tmplist="/tmp/import.$$.plist"
			${PB} -x -c "Print ${ENTRY}" ${PLIST} >${tmplist}
			${PB} -c "Delete ${ENTRY}" ${PLIST}
			${PB} -c "Add ${ENTRY} array" ${PLIST}
			${PB} -c "Add ${ENTRY}:0 dict" ${PLIST}
			${PB} -c "Merge ${tmplist} ${ENTRY}:0" ${PLIST}
			rm -f ${tmplist}
		fi
		${PB} -c "Merge ${addlist} ${ENTRY}" ${PLIST}
		;;
	del)
		i=$(getent_id ${shippath} ${PLIST})
		[ -n "${i}" ] && \
			${PB} -c "Delete Sockets:Listeners:${i}" ${PLIST}
		;;
	esac

	rm -f ${addlist}
	${DEBUG} launchctl unload ${PLIST}
	${DEBUG} launchctl load -w ${PLIST}
	# wait for name resolution to be ready
	[ "${action}" = "add" ] && while :
		do
			chroot ${shippath} \
				${ping} -c 1 localhost >/dev/null 2>&1
			[ $? -eq 0 ] && break
			echo "waiting for resolver..."
			sleep 1
		done
}
