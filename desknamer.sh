#!/usr/bin/env bash

BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
R='\e[0m'

getAllApplications() { find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *.desktop 2>/dev/null; }

getAllCategories() {
	IFS=$'\n'
	for menuItem in $(getAllApplications); do
		sed -n 's/;/ /g; s/ /\n/g; s/^Categories=//p' < "$menuItem"
	done | sort -u
}

searchApplications() {
	{ find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname "$1".desktop || find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *"$1".desktop || head -1 || find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *"$1"*.desktop; } 2>/dev/null | head -1
}

getCategoryComm() {
	local comm="$1"
	if [ -z "${comm##*/*}" ]; then
		menuItem="$comm"
	else
		menuItem="$(searchApplications "$comm")"
	fi
	[ -n "$menuItem" ] && desktopCategories+=($(sed -n 's/;/ /g; s/^Categories=//p' "$menuItem")) || return 1
}

getCategoryNode() {
	node="$1"

	IFS=' '
	for class in $(xprop -id "$node" WM_CLASS 2>/dev/null | cut -d '=' -f 2); do
		getCategoryComm "$(sed 's/.*"\(.*\)".*/\1/' <<< "$class")"
	done
}

getCategories() {
	local pid="$1"

	# accessing process file is faster than ps
	local comm="$({ tr '\0' '\n' < "/proc/$pid/comm"; } 2>/dev/null)"
	[ -z "$comm" ] && return
	children+=("$comm")

	IFS=$'\n'
	((recursive)) && for childPid in "$(ps -o pid= --ppid "$pid" 2>/dev/null)"; do
		getCategories "$childPid"
	done

	getCategoryComm "$comm" || return 1
}

renameDesktops() {
	local desktopIDs="$@"
	IFS=' '
	for desktopID in $desktopIDs; do
		monitorID="$(bspc query --desktop "$desktopID" --monitors)"

		if [ "${monitorBlacklist#*$monitorID}" != "$monitorBlacklist" ] || [ "${desktopBlacklist#*$monitorID}" != "$desktopBlacklist" ]; then
			echo -e " - Not renaming desktopID: $desktopID\n"
			return 0
		fi
		echo " - Renaming desktopID: $desktopID"

		desktopName="$(bspc query --names --desktop "$desktopID" --desktops)"
		echo -e " -- Current Desktop Name: ${GREEN}$desktopName ${R}"

		((verbose)) && echo " -- monitorID: $monitorID"

		desktopIndex="$(bspc query -m "$monitorID" --desktops | grep -n "$desktopID" | cut -d ':' -f 1)"
		echo " -- desktopIndex: $desktopIndex"

		# for node in this desktop, get children processes and categories
		desktopCategories=()
		children=()
		IFS=$'\n'
		for node in $(bspc query -m "$monitorID" -d "$desktopID" -N); do
			pid=$(xprop -id "$node" _NET_WM_PID 2>/dev/null | awk '{print $3}')
			[ "$pid" == "found." ] && pid=""
			((verbose)) && echo " -- Node [PID]: $node [${pid:-NONE}]"


			# try using pid to get categories, otherwise try node's WM_CLASS property
			if [ -n "$pid" ]; then
				getCategories "$pid" || getCategoryNode "$node"
			else
				getCategoryNode "$node"
			fi

		done

		((verbose)) && echo -e " -- All Processes:\n${children[@]}"

		# check programs against custom list of categories
		IFS=' '
		for comm in ${children[@]}; do
			desktopCategories+=("$(2>/dev/null python3 -c "import sys, json; print(json.load(sys.stdin)['applications']['$comm'])" <<< "$config")")
		done

		echo -e " -- All Categories Found:\n${desktopCategories[@]}\n"

		# check config for name with lowest priority
		name=""
		minPriority=100
		IFS=' '
		for category in ${desktopCategories[@]}; do
			priority="$(2>/dev/null python3 -c "import sys, json; print(json.load(sys.stdin)['categories']['$category'][1])" <<< "$config")"
			if [ -n "$priority" ] && [ $(echo "$priority < $minPriority" | bc -l) -eq 1 ]; then
				minPriority="$priority"
				name="$(2>/dev/null python3 -c "import sys, json; print(json.load(sys.stdin)['categories']['$category'][0])" <<< "$config")"
			fi
		done

		## fallback names

		# existing programs, but none recognized
		[ -z "$name" ] && [ "${#children[@]}" -gt 0 ] && name=""

		# or, find custom index name
		[ -z "$name" ] && name="$(2>/dev/null python3 -c "import sys, json; print(json.load(sys.stdin)['indexes']['$desktopIndex'])" <<< "$config")"

		# or, just plain index
		[ -z "$name" ] && name="$desktopIndex"	# no applications

		echo -e " -- New Name: ${BLUE}$name ${R}\n"
		bspc desktop "$desktopID" --rename "$name"
	done
}

renameMonitor() {
	monitorID="$1"
	# ensure monitorID exists in monitorWhitelist and not in monitorBlacklist
	if [ "${monitorBlacklist#*$monitorID}" != "$monitorBlacklist" ]; then
		echo -e "Not renaming monitor: $monitorID\n"
		return 0
	fi
	echo "Renaming monitor: $monitorID"
	IFS=$'\n'
	for desktop in $(bspc query -m "$monitorID" -D); do renameDesktops "$desktop"; done
}

renameAll() {
	echo "Renaming monitors..."
	IFS=$'\n'
	for monitorID in $(bspc query -M); do renameMonitor "$monitorID"; done
}

monitor() {
	bspc subscribe monitor_add monitor_remove monitor_swap desktop_add desktop_remove desktop_swap desktop_transfer node_add node_remove node_swap node_transfer | while read -r line; do	# trigger on any bspwm event

		echo -e "${RED}trigger:${R} $line"
		case "$line" in
			monitor*) renameAll ;;
			desktop_add*|desktop_remove*) renameAll ;;
			desktop_swap*) renameDesktops "$(echo "$line" | awk '{print $3,$5}')" ;;
			desktop_transfer*) renameDesktops "$(echo "$line" | awk '{print $3}')" ;;
			node_add*|node_remove*) renameDesktops "$(echo "$line" | awk '{print $3}')" ;;
			node_swap*|node_transfer*) renameDesktops "$(echo "$line" | awk '{print $3,$6}')" ;;
		esac
	done
}

flag_h=0
recursive=1
mode="monitor"

configFile=~/.config/desknamer/desknamer.json

verbose=0
python=0

children=()
desktopCategories=()

OPTS="hc:nvM:D:lLs:g:"	# colon (:) means it requires a subsequent value
LONGOPTS="help,config:,norecursive,verbose,monitor-blacklist:,desktop-blacklist:,list-applications,list-categories,search:,get:"

parsed=$(getopt --options=$OPTS --longoptions=$LONGOPTS -- "$@")
eval set -- "${parsed[@]}"

while true; do
	case "$1" in
		-h|--help) flag_h=1; shift ;;
		-c|--config) configFile="$2"; shift 2 ;;
		-n|--norecursive) recursive=0; shift ;;
		-v|--verbose) verbose=1; shift ;;

		-M|--monitor-blacklist) monitorBlacklistIn="$2"; shift 2 ;;
		-D|--desktop-blacklist) desktopBlacklistIn="$2"; shift 2 ;;

		-l|--list-applications) mode="list-applications"; shift ;;
		-L|--list-categories) mode="list-categories"; shift ;;
		-s|--search) mode="search"; application="$2"; shift 2 ;;
		-g|--get) mode="get"; application="$2"; shift 2 ;;

		--) shift; break ;;
		*)
			printf '%s\n' "Error while parsing CLI options" 1>&2
			flag_h=1
			;;
	esac
done

HELP="\
Usage: desknamer [OPTIONS]

desknamer.sh monitors your open desktops and renames them according to what's inside.

optional args:
  -c, --config FILE       path to alternate configuration file
  -n, --norecursive       don't inspect windows recursively
  -M \"MONITOR [MONITOR2]...\"
                          specify monitor names or IDs to ignore
  -D \"DESKTOP [DESKTOP2]...\"
                          specify desktop names or IDs to ignore
  -l, --list-applications  print all applications found on your machine
  -L, --list-categories   print all categories found on your machine
  -s, --search PROGRAM    find .desktop files matching *program*.desktop
  -g, --get PROGRAM       get categories for given program
  -v, --verbose           make output more verbose
  -h, --help              show help"

# convert {monitor,desktop} names to ids
IFS=' '
for monitor in $monitorBlacklistIn; do
	found="$(bspc query -m "$monitor" -M) "
	[ $? -eq 0 ] && monitorBlacklist+="$found"
done
for desktop in $desktopBlacklistIn; do
	found="$(bspc query -d "$desktop" -D) "
	[ $? -eq 0 ] && desktopBlacklist+="$found"
done

if ((flag_h)); then
	printf '%s\n' "$HELP"
	exit 0
fi

if [ ! -e "$configFile" ]; then
	echo "error: config file specified does not exist: $configFile"
	exit 1
fi
config="$(cat "$configFile")"

case "$mode" in
	list-applications) getAllApplications ;;
	list-categories) getAllCategories ;;
	monitor) monitor ;;
	search) find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname "*$application"*.desktop 2>/dev/null ;;
	get) getCategoryComm "$application" ;;
esac
