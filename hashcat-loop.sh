#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 </path/to/hashes.txt> <numeric-hash-type>"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

HASHFILE="${1}"
TYPE="${2}"
HASHCAT_BIN="/opt/tools/hashcat/hashcat.bin"
WORDLIST="/data/wordlists/combined.LARGE.txt"
PREVIOUSLY_CRACKED_WORDLIST="/data/wordlists/previously_cracked.txt"
RULES="/opt/tools/hashcat-rules"
TEMP_POTFILE="$(mktemp /tmp/hashcrack.pot.XXXXXXXXXX)"
TEMP_OUTFILE="$(mktemp /tmp/hashcrack.out.XXXXXXXXXX)"
OUTPUT_FILE="/data/output/$(date -I)_$(basename ${HASHFILE}).cracked.txt"

clean_up() {
    echo -e "\nCleaning up temp files...\n"
    cat "${TEMP_POTFILE}" >> "${OUTPUT_FILE}"
    cat "${TEMP_OUTFILE}" >> "${PREVIOUSLY_CRACKED_WORDLIST}"
    rm -f -- "${TEMP_POTFILE}"
    rm -f -- "${TEMP_OUTFILE}"
    echo -e "\nDone...\n"
}

trap clean_up EXIT

# Check if files and directories exist
for file in "${HASHCAT_BIN}" "${WORDLIST}" "${PREVIOUSLY_CRACKED_WORDLIST}"; do
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist"
        exit 1
    fi
done

function run_hashcat() {
    "${HASHCAT_BIN}" --potfile-path "${TEMP_POTFILE}" -m "${TYPE}" -w 4 --bitmap-max 26 --outfile-format=2 --outfile-autohex-disable --outfile "${TEMP_OUTFILE}" -O "${@}"

    HASHCAT_STATUS=$?
    if [ $HASHCAT_STATUS -lt 0 ]; then
        echo "Hashcat failed with error code $HASHCAT_STATUS"
        exit 1
    fi
}

# Check against previously cracked hashes
run_hashcat -a 0 "${HASHFILE}" "${PREVIOUSLY_CRACKED_WORDLIST}"

# Check against previously cracked hashes and ruleset
run_hashcat -a 0 --loopback -r "${RULES}/OneRuleToRuleThemStill.rule" "${HASHFILE}" "${PREVIOUSLY_CRACKED_WORDLIST}"

# Check up to 7 characters, incremetally - upper, lower, digit, some special characters
run_hashcat -a 3 -i -1 '?l?d?u!"£$%^&*()_+@#' "${HASHFILE}" ?1?1?1?1?1?1?1

# Check with big wordlist
run_hashcat -a 0 "${HASHFILE}" "${WORDLIST}"

# Check with big wordlist and rules
run_hashcat -a 0 --loopback -r "${RULES}/OneRuleToRuleThemStill.rule" "${HASHFILE}" "${WORDLIST}"

# Check 8 characters - upper, lower, digit, some special characters
run_hashcat -a 3 -1 '?l?d?u!"£$%^&*()_+@#' "${HASHFILE}" ?1?1?1?1?1?1?1?1

# Check up to 12 characters - ALL - last ditch effort
run_hashcat -a 3 -i "${HASHFILE}" ?a?a?a?a?a?a?a?a?a?a?a?a
