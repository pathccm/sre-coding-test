#!/usr/bin/env bash
###
# Simple wrapper script around semgrep and trufflehog scans
#
# Allows for defining a specific folder for quicker "sub" scans,
# defaults to scanning entire monorepo
#
# e.g. bash scripts/security_scan.sh packages/
###
set -ou pipefail

START=$(date +%s)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
pushd "${SCRIPT_DIR}" > /dev/null || exit 1
pushd "$(git rev-parse --show-toplevel)" > /dev/null || exit 1

if [[ -n "$*" ]]; then
	_SCANPATH="$*"
else
	_SCANPATH="$(pwd)"
fi
CI=${CI:-false}
TRUFFLE_ONLY=${TRUFFLE_ONLY:-false}
SEMGREP_ONLY=${SEMGREP_ONLY:-false}
DEBUG=${DEBUG:-false}
exit_code=0

TRUFFLE_SWITCHES="--exclude-paths=.trufflehogignore --fail --only-verified --no-update --results=verified --github-actions --since-commit=main"

if [[ "${DEBUG}" == "true" ]]; then
	TRUFFLE_SWITCHES+=" --debug"
fi
if [[ "${CI}" != "true" ]]; then
	if [[ "${SEMGREP_ONLY}" != "true" || "${TRUFFLE_ONLY}" == "true" ]]; then
		echo "Scanning for secrets.."
		if [[ -f .trufflehog_settings.yml ]]; then
			excluded_detectors="--exclude-detectors=$(yq eval '.excluded_detectors[]' .trufflehog_settings.yml | xargs | sed 's/ /,/')"
			# shellcheck disable=SC2086
			trufflehog git "${excluded_detectors}" ${TRUFFLE_SWITCHES} "file://$(pwd)"
		else
			# shellcheck disable=SC2086
			trufflehog git ${TRUFFLE_SWITCHES} "file://$(pwd)"
		fi
		exit_code=$?
	fi
fi

if [[ "${TRUFFLE_ONLY}" != "true" || "${SEMGREP_ONLY}" == "true" ]]; then
	# we use --no-git-ignore so .semgrepignore doesn't get overridden.
	# If .semgrepignore gets overridden, we end up scanning large parts of .yarn, which is slow and useless
	_OPTIONS="--disable-version-check --no-autofix --metrics off --error --no-git-ignore"
	if [[ "${DEBUG}" == "true" ]]; then
		_OPTIONS+=" --verbose"
	else
		_OPTIONS+=" -q"
	fi
	_RULESETS="$(yq eval '.rulesets[]' .semgrep_settings.yml | sed 's/^/ -c /' | xargs)"
	_EXCLUDE="$(yq eval '.excluded[]' .semgrep_settings.yml | sed 's/^/ --exclude-rule /' | xargs)"

	printf "\nSAST scan for security/functional issues..\n"
	if [[ "${CI}" == "false" ]]; then
		nosem_lines=$(grep --exclude-dir={.yarn,node_modules,.git,build,built,dist,docs} nosemgrep "$(pwd)" -RI | grep -Evc "\.md:")
		printf "There are ~%s nosemgrep lines in the code base\n" "${nosem_lines}"
	fi
	ignored_rules=$(yq eval '.excluded | length' .semgrep_settings.yml)
	rulesets=$(yq eval '.rulesets | length' .semgrep_settings.yml)
	printf "There are %s ignored rules from %s rulesets\n\n" "${ignored_rules}" "${rulesets}"

	# shellcheck disable=SC2086
	semgrep scan ${_OPTIONS} ${_RULESETS} ${_EXCLUDE} ${_SCANPATH}
	_exit=$?
	if [[ "${exit_code}" -eq 0 ]]; then
		exit_code="${_exit}"
	fi
fi

popd > /dev/null || exit 1
popd > /dev/null || exit 1

ended=$(date +%s)
elapsed=$((ended-START))
echo "Security scans took ${elapsed} seconds"
if [[ "${exit_code}" -ne 0 ]]; then
	echo "A SCAN FAILED!"
fi
exit "${exit_code}"
