awk=$(which awk)
cat=$(which cat)
chmod=$(which chmod)
chown=$(which chown)
chroot=$(which chroot)
curl=$(which curl)
cp=$(${debug}which cp)
date=$(which date)
grep=$(which grep)
groupadd=$(which groupadd)
gpg=$(which gpg)
id=$(which id)
ifconfig=$(which ifconfig)
ls=$(which ls)
od=$(which od)
pax="${debug}$(which pax) -rwpe"
ping=$(which ping)
pkgin="$(which pkgin)"
pkg_info="$(which pkg_info)"
mkdir="$(which mkdir) -p"
mount=$(which mount)
rm="$(which rm) -f"
rsync="$(which rsync) -av"
sh=$(which sh)
shasum=$(which shasum)
sort=$(which sort)
sudo=$(which sudo)
sleep=$(which sleep)
tar=$(which tar)
touch=$(which touch)
tr=$(which tr)
umount=$(which umount)
useradd=$(which useradd)
ARCH=$(uname -m)
DDATE=$(date +%Y%m%d)
SHELLRC=~/.$(echo $SHELL | awk -F/ '{print$NF}')rc
PKGIN_VARDB="$(${pkg_info} -QVARBASE pkgin)/db/pkgin"
OS=$(uname -s)

# columns sizes for ls
cols=${COLUMNS:-$(tput cols)}
col1=$(($((${cols} * 23)) / 100))
col2=$(($((${cols} * 22)) / 100))
col3=$(($((${cols} * 30)) / 100))
col4=$(($((${cols} * 10)) / 100))