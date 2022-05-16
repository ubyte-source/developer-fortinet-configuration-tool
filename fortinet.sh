#!/bin/bash

while getopts i: options; do
  case ${options} in
  i) ID=${OPTARG} ;;
  esac
done

((ID = ID * 64))

declare -a RESPONSE=()

if ! [ -v ID ]; then
  RESPONSE+=("-i: Specifies the ID connectivity device.")
fi

if [ ${#RESPONSE[@]} -ne 0 ]; then
  printf '%s\n' "${RESPONSE[@]}"
  exit 1
fi

unset RESPONSE

dec2ip() {
  local ip dec=$1
  for e in {3..0}; do
    ((octet = dec / (256 ** e)))
    ((dec -= octet * 256 ** e))
    [[ $2 == $(echo -e "\x2D") ]] && octet=$(printf "%03d" $octet)
    ip+=$delimiter$octet
    delimiter=$2
  done

  printf '%s' "$ip"

  return 0
}

ip2dec() {
  local a b c d ip=$1
  IFS=$2 read -r a b c d <<<"$ip"

  a=$(expr $a + 0)
  b=$(expr $b + 0)
  c=$(expr $c + 0)
  d=$(expr $d + 0)

  printf '%d' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
  return 0
}

SetStatic() {
  cat $1 | grep -oE 10000 | while read id; do
    ((newstatic = id + ID))
    sed -i -E "s|(\b)($id)(\b)|\1${newstatic}\3|ig" $1
    break
  done

  return 0
}

Fortigate() {
  local regex=$(printf '(([0-9]{1,3}|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\%s){2,3}([0-9]{1,3}|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))' $1)
  local named='^(([0-1][0-9][0-9]|2([0-4][0-9]|5[0-5]))\-){2}([0-9]{1,3}|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$'
  local array=()

  cat $2 | grep -oE ${regex} | while read ip; do

    if [[ $ip =~ ${named} ]]; then
      toint="92-$ip"
      toint=$(ip2dec $toint $1)
    else
      ! [[ $ip =~ ^10 ]] && continue;
      toint=$(ip2dec $ip $1)
    fi

    [[ $toint =~ 181700296|181700306|167772160|176422915 ]] && continue
    [[ ${array[*]} == *"$toint"* ]] && continue
    array+=($toint)

    ((toint = toint + ID))
    replace=$(dec2ip $toint $1)

    [[ $ip =~ ${named} ]] && replace=${replace:4}
    sed -i -E "s|(\b)($ip)(\b)|\1${replace}\3|ig" $2

  done

  return 0
}

TEMPORARY=$(mktemp -d)
F40="${TEMPORARY}/40F.conf"
FVM="${TEMPORARY}/FVM.conf"

cp ./template/40F.conf $F40
cp ./template/FVM.conf $FVM

SYMBOLS=("." "-")
for s in "${SYMBOLS[@]}"; do
  Fortigate $s $F40
  Fortigate $s $FVM
done

SetStatic $FVM

ZIP=$(mktemp)
ZIP="$ZIP.zip"
zip -qqj ${ZIP} ${F40} ${FVM}

cat ${ZIP}

exit 0
