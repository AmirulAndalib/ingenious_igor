#!/bin/bash

if [[ $Season == "01" || $Season == "03" ]]; then
  export lastEp="26"
elif [[ $Season == "02" ]]; then
  export lastEp="25"
fi

if [[ $EpNum == "$lastEp" ]]; then
  printf "End of line.\nAll files are transCoded.\nHave a good day!\n"
else
  export NextEpCode=$(printf "%02d" "$((EpNum + 1))")
  curl -X POST \
    -H "Authorization: token ${PAT}" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/main.yml/dispatches \
    -d '{
      "ref": "main",
      "inputs": {
        "EpCode": "'"$NextEpCode"'"
      }'
fi
