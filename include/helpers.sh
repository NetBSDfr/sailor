epoch_to_hms()
{
	secs=${1}

	h=$(( secs / 3600 ))
	m=$(( ( secs / 60 ) % 60 ))
	s=$(( secs % 60 ))

	printf "%02d:%02d:%02d\n" $h $m $s
}
