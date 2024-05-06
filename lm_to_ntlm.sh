#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 </path/to/LMhashes.txt> </path/to/NTLMhashes.txt>"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

LM_HASHFILE="${1}"
NTLM_HASHFILE="${2}"
HASHCAT_BIN="/opt/tools/hashcat/hashcat.bin"
RULES="/opt/tools/hashcat/rules"
TEMP_POTFILE="$(mktemp)"
TEMP_OUTPUT="$(mktemp)"
OUTPUT_FILE="/data/output/$(date -I)_$(basename ${HASHFILE})_NTLM.cracked.txt"

clean_up() {
    cat "${TEMP_POTFILE}" >> "${OUTPUT_FILE}"
    rm -f -- "${TEMP_POTFILE}"
    rm -f -- "${TEMP_OUTPUT}"
}

trap clean_up EXIT

# Check if files and directories exist
for file in "${HASHCAT_BIN}"; do
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist"
        exit 1
    fi
done

function run_hashcat() {
    "${HASHCAT_BIN}" --potfile-path "${TEMP_POTFILE}" -w 4 -O "${@}"
    if [ $? -ne 0 ]; then
        echo "Hashcat failed with error code $?"
        exit 1
    fi
}

# Crack the LM hash, in two parts - first 7 characters, then the last 7 characters
run_hashcat -m 3000 -a 3 -o "${TEMP_OUTPUT}" --outfile-format=2 -i "${LM_HASHFILE}" ?a?a?a?a?a?a?a

# Crack the NTLM using the two parts of the LM hash
run_hashcat -m 1000 -a 0 --loopback --rules "${RULES}/toggles-lm-ntlm.rule" "${NTLM_HASHFILE}" "${TEMP_OUTPUT}"

clean_up
