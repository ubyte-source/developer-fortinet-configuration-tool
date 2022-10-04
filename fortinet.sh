#!/bin/bash

! [ -v JQ ] && export JQ=/usr/bin/jq
! [ -v CURL ] && export CURL=/usr/bin/curl

while getopts e:p:m:s:d: options; do
  case ${options} in
  e) CAMELOT_EMAIL=${OPTARG} ;;
  p) CAMELOT_PASSWORD=${OPTARG} ;;
  m) FORTIGATE_MAC_ADDRESS=${OPTARG} ;;
  s) FORTIGATE_SERIAL_NUMBER=${OPTARG} ;;
  d) DETAIL=${OPTARG} ;;
  esac
done

declare -a RESPONSE=()

if ! [ -v CAMELOT_EMAIL ]; then
  RESPONSE+=("-e: Specifies the camelot credential e-mail.")
fi

if ! [ -v CAMELOT_PASSWORD ]; then
  RESPONSE+=("-p: Specifies the camelot credential password.")
fi

if ! [ -v FORTIGATE_MAC_ADDRESS ]; then
  RESPONSE+=("-m: Specifies the MAC address of Fortigate device.")
fi

if ! [ -v FORTIGATE_SERIAL_NUMBER ]; then
  RESPONSE+=("-s: Specifies the serial-numebr of Fortigate device.")
fi

if [ ${#RESPONSE[@]} -ne 0 ]; then
  printf '%s\n' "${RESPONSE[@]}"
  exit 1
fi

unset RESPONSE

URI="https://engine.energia-europa.com/api/machine/connectivity"
[[ -v DETAIL ]] && URI="${URI}/detail/${DETAIL}" || URI="${URI}/create"

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

Create() {
  local authorization=$($CURL -k -X POST -F "email=$CAMELOT_EMAIL" -F "password=$CAMELOT_PASSWORD" https://login.energia-europa.com/api/iam/user/login | $JQ -r .authorization)
  local request=$($CURL -k -H "x-authorization: $authorization"  -F "connectivity_mac=$FORTIGATE_MAC_ADDRESS" -F "connectivity_serial=$FORTIGATE_SERIAL_NUMBER" ${URI})
  local request_status=$($JQ -rc .status <<< "$request")
  if [ $request_status = true ]; then
    local created=$($JQ -rc .data <<< "$request")
    $JQ -rc .data <<< "$request"
  fi

  return 0
}

SetStatic() {
  cat $2 | grep -oE 10000 | while read id; do
    ((newstatic = id + $1))
    sed -i -E "s|(\b)($id)(\b)|\1${newstatic}\3|ig" $2
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
      ! [[ $ip =~ ^0?10 ]] && continue;
      toint=$(ip2dec $ip $1)
    fi

    [[ $toint =~ 181700296|181700306|167772160|176422915|180944897 ]] && continue
    [[ ${array[*]} == *"$toint"* ]] && continue
    array+=($toint)

    ((toint = toint + $3))
    replace=$(dec2ip $toint $1)

    [[ $ip =~ ${named} ]] && replace=${replace:4}
    sed -i -E "s|(\b)($ip)(\b)|\1${replace}\3|ig" $2

  done

  return 0
}

create=$(Create)
if [[ $create ]]; then

  TEMPORARY=$(mktemp -d)
  F40="${TEMPORARY}/40F.conf"
  FVM="${TEMPORARY}/FVM.conf"

  cp ./template/40F.conf $F40
  cp ./template/FVM.conf $FVM

  id=$(echo "$create" | $JQ -r .id_connectivity)

  ((id = id - 1))
  ((id = id * 64))

  SYMBOLS=("." "-")
  for s in "${SYMBOLS[@]}"; do
    Fortigate $s $F40 $id
    Fortigate $s $FVM $id
  done

  SetStatic $id $FVM

  ZIP=$(mktemp)
  ZIP="$ZIP.zip"
  zip -qqj ${ZIP} ${F40} ${FVM}

  cat ${ZIP}

fi

exit 0
