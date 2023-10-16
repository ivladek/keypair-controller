#!/bin/bash

# keypair-controller
# v02.00 16.10.2023
#   by Vladislav Kirilin
#   @ivladek / ivladek@me.com
#
# securely controls key pairs on local host
#


# number of trials for assymetric keys
AKtrials=512
# number of trials for ssymetric keys
SKtrials=1048576

Help()
{
  # Display Help
  [[ "${1}" == "" ]] || echo "!!! ${1} !!!"
  echo -e "\n\nKeypair controller - generate, add to agent, show information in secure manner"
  echo "Syntax: ./$(basename ${0}) -d -n [[-c] [-l] | -s] [-p]"
  echo "options:"
  echo "  h           - print this Help"
  echo "  d path      - target path"
  echo "  n name      - keypair name"
  echo "  c \"comment\" - keypair decription"
  echo "  l NNN       - use RSA algorithm with key length or ED25519 if omitted"
  echo "  s pathname  - use unecrypted secret key and regenerate config and public"
  echo "  p           - ask secret key password instead of auto generation"
  echo -e "\nuse KEYPAIR_CONFIG_PASS variable to pass password to the script"
  echo -e "\n./$(basename ${0}) -d ~/Documents/keypairs -n github.com -c \"github.com / vladek@me.com\""
  echo "  generate the new keypair using ED25519 in directory ~/Documents/keypairs"
  echo -e "\n./$(basename ${0}) -d ~/Documents/keypairs -n gitlab.com -s ~/Documents/secrets/gitlab.com.key"
  echo "  import unecrypted secret key, generate the new config and public key"
  echo -e "\n./$(basename ${0}) -d ~/Documents/keypairs -n git.corp.com -l 4096 -c \"corp git / vladek@corp.com\" -p"
  echo "  generate the new keypair using RSA, ask for secret key file password"
  echo
  exit
}

KEYtype="ed25519"
KEYlen=256
ASKpass="no"
unset FILEold
while [[ $# -gt 0 ]]; do
  case $1 in
    -h)
      Help
      exit
    ;;
    -d)
      KEYpath=$(dirname ${2})/$(basename ${2})
      shift
    ;;
    -n)
      KEYname="${2}"
      shift
    ;;
    -c)
      KEYcomment="${2}"
      shift
    ;;
    -l)
      KEYtype="rsa"
      KEYlen=${2}
      shift
    ;;
    -s)
      FILEold="${2}"
      shift
    ;;
    -p)
      ASKpass="yes"
    ;;
  esac
  shift
done
FILEconfig="${KEYpath}/${KEYname}.config"
FILEsecret="${KEYpath}/${KEYname}.secret"
FILEpublic="${KEYpath}/${KEYname}.public"

echo -e "\ntarget directory: ${KEYpath}"
echo -n "  status        : "
[[ -d "${KEYpath}" ]] || Help "WRONG"
chmod 700 "${KEYpath}"
echo "ok"
echo "  opened for write"

echo -en "\nkeypair      : "
[[ "${KEYname}" == "" ]] && Help "DOES NOT DEFINED"
echo "${KEYname}"
echo "  config file: ${FILEconfig}"
echo "  secret key : ${FILEsecret}"
echo "  public key : ${FILEpublic}"

echo -e "\nconfig file password: "
if [[ "${KEYPAIR_CONFIG_PASS}" == "" ]]
then
  echo -n "  please enter      : "
  read KEYPAIR_CONFIG_PASS
  export KEYPAIR_CONFIG_PASS
else
  echo "  read from variable: ${KEYPAIR_CONFIG_PASS}"
fi

echo -ne "\nkeypair data: reading from "
unset KEYpwd
if [[ "${FILEold}" != "" ]]
then
  echo "unecrypted secret key file ${FILEold}"
  echo "  get public key"
  KEYinfo=$(ssh-keygen -l -f "${FILEold}" 2>/dev/null)
  [[ $? == 0 ]] || Help "CAN NOT READ SECRET KEY"
  echo "  get secret key"
  cp -f "${FILEold}" "${FILEsecret}.tmp"
  cp -f "${FILEsecret}.tmp" "${FILEsecret}"
  rm -f "${FILEsecret}.tmp"
  chmod 600 "${FILEsecret}"
  ssh-keygen -p -P "" -N "" -f "${FILEsecret}" &>/dev/null
  KEYsecret=$(cat "${FILEsecret}")
  KEYdata=($KEYinfo)
  KEYlen=${KEYdata[0]}
  [[ ${KEYlen} == 256 ]] && KEYtype="ed25519" || KEYtype="rsa"
  COMMENTstart=$((1+${#KEYdata[0]}+1+${#KEYdata[1]+1}))
  COMMENTlen=$((${#KEYinfo}-${COMMENTstart}-${#KEYdata[${#KEYdata[@]}-1]}-1))
  KEYcomment=${KEYinfo:${COMMENTstart}:${COMMENTlen}}
  echo "  delete config file"
  rm -f "${FILEconfig}"
elif [[ -f "${FILEconfig}" ]]
then
  echo "file"
  base64 -Dd -i "${FILEconfig}" | openssl enc -d -aes-256-cbc -md sha512 -iter ${SKtrials} -salt -pass env:KEYPAIR_CONFIG_PASS -out "${FILEconfig}.tmp"
  [[ $? == 0 ]] || Help "CAN NOT DECODE CONFIG FILE"
  KEYcomment=$(cat "${FILEconfig}.tmp" | jq -r '.description')
  KEYtype=$(cat "${FILEconfig}.tmp"    | jq -r '.algorithm')
  KEYlen=$(cat "${FILEconfig}.tmp"     | jq -r '.length')
  KEYpwd=$(cat "${FILEconfig}.tmp"     | jq -r '.password')
  rm -f "${FILEconfig}.tmp"
else
  echo "script parameters"
fi
echo "  type      : ${KEYtype}"
echo "  length    : ${KEYlen}"
echo "  comment   : \"${KEYcomment}\""
if [[ "${KEYpwd}" == "" ]]
then
  if [[ "${ASKpass}" == "no" ]]
  then
    KEYpwd=$(echo ${RANDOM}$(date)${RANDOM}$(ls -lR /tmp/)${RANDOM} | shasum | base64 | head -c 50)
    echo "  password  : ${KEYpwd} (generated)"
  else
    echo -n "  password ? "
    read KEYpwd
    export KEYpwd
  fi
else
  echo "  password  : ${KEYpwd} (read from config)"
fi

if [[ ! -f "${FILEconfig}" ]]
then
  echo -e "\ncreate config file"
  echo "{
    \"description\": \"${KEYcomment}\",
    \"algorithm\"  : \"${KEYtype}\",
    \"length\"     : ${KEYlen},
    \"password\"   : \"${KEYpwd}\"
  }" | openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter ${SKtrials} -salt -pass env:KEYPAIR_CONFIG_PASS | base64 -o "${FILEconfig}"
  echo "  unload keypair from keychain"
  ssh-add -q --apple-use-keychain -d "${FILEsecret}" &> /dev/null
  if [[ "${FILEold}" == "" ]]
  then
    echo "  deleting keypair files"
    rm -f "${FILEsecret}"
    rm -f "${FILEpublic}"
  fi
fi

if [[ ! -f "${FILEsecret}" ]]
then
  echo -en "\nkeypair generation ... "
  ssh-keygen -q -t ${KEYtype} -b ${KEYlen} -C "${KEYcomment}" -P "${KEYpwd}" -a ${AKtrials} -f "${FILEsecret}" &>/dev/null
  [[ $? == 0 ]] || Help "ERROR"
  mv "${FILEsecret}.pub" "${FILEpublic}"
  echo done
elif [[ -f "${FILEold}" ]]
then
  echo -en "\nsecret key file encryption ... "
  ssh-keygen -q -p -P "" -N "${KEYpwd}" -a ${AKtrials} -f "${FILEsecret}" &>/dev/null
  echo done
  echo "  write public key file"
  rm -f "${FILEpublic}"
  ssh-keygen -y -f "${FILEold}" > "${FILEpublic}"
fi

echo -e "\nsecret key"
KEYhash=($(ssh-keygen -l -f "${FILEsecret}"))
echo "  hash: ${KEYhash[1]}"
cp "${FILEsecret}" "${FILEsecret}.tmp"
chmod 600 "${FILEsecret}.tmp"
ssh-keygen -q -p -P "${KEYpwd}" -N "" -f "${FILEsecret}.tmp" &> /dev/null
echo "  secret key (unencrypted)"
cat "${FILEsecret}.tmp"
rm -f "${FILEsecret}.tmp"

echo -e "\npublic key"
echo "  from file"
cat "${FILEpublic}"
echo "  from secret key"
ssh-keygen -y -P "${KEYpwd}" -f "${FILEsecret}"

echo -e "\ncheck ssh-agent"
echo "  (re)loading all keys to agent using Keychain"
ssh-add -q --apple-load-keychain
echo -n "  checking secret key presence in agent: "
ssh-add -l | grep "${KEYhash[1]}" > /dev/null
if [[ $? == 0 ]]
then
  echo "loaded"
else
  echo "not exists, adding"
expect << EOF
  spawn ssh-add -q --apple-use-keychain "${FILEsecret}"
  expect "Enter passphrase"
  send "${KEYpwd}\r"
  expect eof
EOF
fi

echo -e "\nkeys loaded to agent"
ssh-add -l

echo -e "\nrestrict access rights back to read only"
chmod 400 "${FILEconfig}"
chmod 400 "${FILEsecret}"
chmod 400 "${FILEpublic}"
chmod 500 "${KEYpath}"

echo -e "\n\ndone."
