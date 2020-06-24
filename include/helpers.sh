is_umounted() {
	if ! ${mount}|${grep} ${shippath}/${1} >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

wait_umount()
{
	while :
	do
		${umount} ${shippath}/${1} >/dev/null 2>&1
		if is_umounted ${1}; then break; fi
		echo "waiting for ${1} to be released..."
		sleep 1
	done
}

epoch_to_hms()
{
	secs=${1}

	h=$(( secs / 3600 ))
	m=$(( ( secs / 60 ) % 60 ))
	s=$(( secs % 60 ))

	printf "%02d:%02d:%02d\n" $h $m $s
}

confirm()
{
	confirm_msg="${1}"
	err_msg="${2}"
	default_msg="${3}"
	while true
	do
		read -p "${confirm_msg}" yn
		case ${yn} in
			[y])
				break
				;;
			[N])
				printf "${err_msg}\n"
				exit 1
				;;
			*)
				confirm_msg=${default_msg}
				continue
				;;
		esac
	done
}
