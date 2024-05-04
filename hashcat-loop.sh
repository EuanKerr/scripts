#!/bin/bash
shopt -s expand_aliases

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 </path/to/hashes.txt> <numeric-hash-type>"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

hashfile="${1}"
type="${2}"
hashcat_bin="/opt/tools/hashcat/hashcat.bin"
hashcat_pot="/data/potfiles/hashcat.potfile"
temp_potfile="$(mktemp)"
output_file="$(basename ${hashfile})"

trap '{ echo -e "\nCatching exit, copying temp potfiles to... ${hashcat_pot}"; \
        cat "$temp_potfile" >> "$hashcat_pot"; \
        cat ${temp_potfile} | tee -a /data/output/$(date -I)-${output_file}-cracked.txt; \
        rm -f -- "$temp_potfile"; \
        }' EXIT

wordlist="/data/wordlists/combined.LARGE.txt"

echo "checking main potfile first for hashes - this will speed up rest of runs, this will take a few mins..."
${hashcat_bin} --potfile-path ${hashcat_pot} -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" -o ${temp_potfile} --show

# use the temp potfile to speed up initial searching - we already know the rest don't exist in our main potfile
alias hashcat="${hashcat_bin} --potfile-path ${temp_potfile}"

hashcat -m "${type}" -a 3 -w 4 -O "${hashfile}" -i -1 '?l?d?u!"£$%^&*()_+@#' ?1?1?1?1?1?1?1?1

hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/OneRuleToRuleThemAll.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/passphrase-rule1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/passphrase-rule2.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/Incisive-leetspeak.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/InsidePro-HashManager.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/InsidePro-PasswordsPro.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlC-insert_00-99_1950-2050_toprules_0_F.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlC-insert_space_and_special_0_F.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlC-insert_top_100_passwords_1_G.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlC.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlCv1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/T0XlCv2.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/best64.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/combinator.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/d3ad0ne.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/d3adhob0.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/dive.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/generated.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/generated2.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/generated3.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/hob064.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/leetspeak.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/oscommerce.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/rockyou-30000.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/specific.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/toggles1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/toggles2.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/toggles3.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/toggles4.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/toggles5.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/unix-ninja-leetspeak.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hashorg.v6.hybrid.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hashorg.v6.one.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hashorg.v6.popular.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hashorg.v6.random.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hashorg.v6.raw1m.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.hybrid.royce.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.one.royce.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.popular.royce.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/hashcat/rules/pantagrule.random.royce.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-o1i1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-i1o1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-o1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nsa64.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/_NSAKEY.v2.dive.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-o2.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-append4.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/T0XlC_3_rule.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/T0XlC_insert_HTML_entities_0_Z.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-i1.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-repeater-i.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/_NSAKEY.v1.dive.rule
hashcat -m "${type}" -a 0 -w 4 -O "${hashfile}" "${wordlist}" --loopback -r /opt/tools/hashcat-rules/nyxgeek-i2.rule

hashcat -m "${type}" -a 3 -w 4 -O "${hashfile}" -1 '?l?d?u!"£$%^&*()_+@#' ?1?1?1?1?1?1?1?1
hashcat -m "${type}" -a 3 -w 4 -O "${hashfile}" -i ?a?a?a?a?a?a?a?a?a?a?a

cat ${temp_potfile} >>${hashcat_pot}
cat ${temp_potfile} | tee ~/$(date -I)-${output_file}-cracked.txt
rm -f ${temp_potfile}
