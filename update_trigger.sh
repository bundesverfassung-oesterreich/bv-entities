#!/bin/bash
# this script can be run on a system to get the current version of the 
# workflow trigger script
# just make shure to provide the right raw-url
# the file gets stored in the same directory as the update script
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ $script_dir == "" ]]; then script_dir="."; fi
# # test just in case something went wrong, dont want to write to  "/"
new_file_name="${script_dir}/transkribus_trigger.sh"
raw_url="https://raw.githubusercontent.com/bundesverfassung-oesterreich/bv-entities/main/bv-entities_transkribus_trigger.sh"
curl -s "$raw_url" -o "$new_file_name"
chmod +x "$new_file_name"
