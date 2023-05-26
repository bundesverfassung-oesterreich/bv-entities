#!/bin/bash
# this script is meant to trigger workflows in https://github.com/bundesverfassung-oesterreich/bv-entities from goobi
# Handle with care! It might contain credentials!
# make shure to uncomment the wanted workflow and to provide a github token
GITHUB_USER_TOKEN=""
# this worklow does nothing, for testing only
# WORKFLOW_FILENAME="test_workflow.yml"
# this is the productive worklflow
# WORKFLOW_FILENAME="transcribus_import.yml"

status=$(curl --request POST \
  --url "https://api.github.com/repos/bundesverfassung-oesterreich/bv-entities/actions/workflows/$WORKFLOW_FILENAME/dispatches" \
  --header "Accept: application/vnd.github+json" \
  --header "authorization: token $GITHUB_USER_TOKEN" \
  --data '{"ref": "main"}')

# this echos curls status code on stdout if something went wrong or "post request successful" if curling worked. Could be logged to file.
# also binary exitcode is returned, can be checked via $?, 1 being error, 0 being success
# results can be checked here to: https://github.com/bundesverfassung-oesterreich/bv-entities/actions
if [ -n "$status" ]
then
  echo "$status"
  exit 1
else
  echo "post request successful"
  exit 0
fi