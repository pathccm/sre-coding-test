#!/usr/bin/env bash

###
# Create a folder structure like
# - folders
# - - folder1
# - - - 1
# - - - - 0.txt
# - - folder2
# - - - 1
# - - - - 0.txt
# with all files/folders creation and modification times set to <days> in the past
# e.g. folder1 -> one day in the past, folder2 -> two days, etc.
# This structure should give us a nice framework to practice making some backups from!
#
# *****NOTE*****
# THIS SCRIPT HAS NOT BEEN VALIDATED ON WINDOWS IN ANY WAY.
# WHILE IT *SHOULD* WORK, THERE IS NO GUARANTEE ALL THE EXPECTED
# BASH FUNCTIONS AND OTHER UNIX COMMANDS WILL BE AVAILABLE.
###

set -eou pipefail
SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
pushd "${SCRIPT_DIR}" > /dev/null || exit 1

set +e
date --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
	DATETYPE="darwin"
else
	DATETYPE="gnu"
fi
set -e

# Defaults that allow for env var control
ROOT_DIR=${ROOT_DIR:-folders}
DAYS=${DAYS:-35}
DIR_RAND_ROOT=${DIR_RAND_ROOT:-10}
FILE_RAND_ROOT=${FILE_RAND_ROOT:-5}

function help() {
	echo "$0"
	printf "\nThis script supports CLI args and env vars. Both settings are defined below:\n"
	echo "--root-dir/ROOT_DIR"
	printf "\tset the folder we'll create all files/etc. under (defaults to ./${ROOT_DIR})\n"
	echo "--days/DAYS"
	printf "\tthe number of days to create files/etc. for (defaults to ${DAYS})\n"
	echo "-d/--dirs/DIR_RAND_ROOT"
	printf "\tthe random seed for the number of directories to create per day (defaults to ${DIR_RAND_ROOT})\n"
	echo "-f/--files/FILE_RAND_ROOT"
	printf "\tthe random seed for the number of files to create per directory (defaults to ${FILE_RAND_ROOT})\n"
	exit
}

# support CLI switches as well
while [[ $# -gt 0 ]]; do
	case $1 in
		--root-dir)
			ROOT_DIR="$2"
			shift 2
			;;
		--days)
			DAYS="$2"
			shift 2
			;;
		-d|--dirs)
			DIR_RAND_ROOT="$2"
			shift 2
			;;
		-f|--files)
			FILE_RAND_ROOT="$2"
			shift 2
			;;
		-h|--help)
			help
			exit 0
		;;
	*) echo "Unknown CLI option for 'create-folders.sh': $1"
		exit 1
		;;
	esac
done

function newTimes() {
	# set modify/creation times to the past
	if [[ "${DATETYPE}" == "gnu" ]]; then
		datestr="$(date -d "$2 days ago" "+%Y-%m-%dT%H:%M:%S")"
		modifystr="$(date -d "$2 days ago" "+%Y%m%d%H%M.%S")"
	else
		datestr="$(date -v-$2d "+%Y-%m-%dT%H:%M:%S")"
		modifystr="$(date -v-$2d "+%Y%m%d%H%M.%S")"
	fi
	# GNU touch doesn't support `-d -t` on one line
	touch -d "${datestr}" "$1"
	touch -t "${modifystr}" "$1"
}

# ensure we only use standard characters
LC_ALL=C
export LC_ALL

starttime=$(date '+%s')
created=0
total_dirs=0
rm -rf "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}"
pushd "${ROOT_DIR}" > /dev/null || exit 1
for ((day=1;day<=DAYS;day++)); do
	echo "Creating data for day ${day}"
	mkdir -p "folder${day}"
	pushd "folder${day}" > /dev/null || exit 1
	DIR_COUNT=$(( RANDOM % DIR_RAND_ROOT + 10 ))
	total_dirs=$(( total_dirs + DIR_COUNT ))
	for ((i=1;i<=DIR_COUNT;i++)); do
		mkdir -p "${i}"
		pushd "${i}" > /dev/null || exit 1
		FILE_COUNT=$(( RANDOM % FILE_RAND_ROOT + 5 ))
		for ((j=0;j<=FILE_COUNT;j++)); do
			chars=$(( RANDOM % 10000 ))
			if [[ "${chars}" -gt 0 ]]; then
				# tr helps avoid non-printing characters (which may trim the size down a bit)
				head -c "${chars}" /dev/urandom | tr -dC '[:print:]' > "${j}.txt"
			else
				touch "${j}.txt"
			fi
			newTimes "${j}.txt" "${day}"
			created=$(( created + 1 ))
		done
		popd > /dev/null || exit 1
		newTimes "${i}" "${day}"
	done
	popd > /dev/null || exit 1
	newTimes "day${day}" "${day}"
done
# back up the stack to our script directory
popd > /dev/null || exit 1
endtime=$(date '+%s')

echo "Created ${created} files across ${total_dirs} directories"
echo "Space Used: $(du -sh "${ROOT_DIR}" | awk '{print $1}')"
echo "Took $((endtime - starttime)) seconds"

# for hygiene purposes only
popd > /dev/null || exit 1
