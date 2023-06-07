#!/bin/bash
# this script is meant to trigger workflows in https://github.com/bundesverfassung-oesterreich/bv-entities from goobi
# Handle with care! It might contain credentials!
# make shure to uncomment the wanted workflow and to provide a github token
GITHUB_USER_TOKEN=""
# this worklow does nothing, for testing only
WORKFLOW_FILENAME="test_workflow.yml"
# this worklfow also does nothing but it always fails
# WORKFLOW_FILENAME="test_error_workflow.yml"
# this is the productive worklflow
# WORKFLOW_FILENAME="transcribus_import.yml"
# this var decides whether python or jq is used to deal with json results,
# set to true if you dont want any python & to "false" if you want to use python
no_py="false"
# some vars
worflow_status_url="https://api.github.com/repos/bundesverfassung-oesterreich/bv-entities/actions/workflows/$WORKFLOW_FILENAME/runs"
seconds_2_wait_4_request=10
# set this global limit to make shure loops terminate / api doesn't get upset
maxwaits=20
currentwaits=0

function get_message {
  result=$(curl -s $worflow_status_url --header "authorization: token $GITHUB_USER_TOKEN")
  if [[ $no_py == "false" ]]
  then
    message=$(echo $result | python3 -c "import sys, json; json_data=json.load(sys.stdin); print(json_data['message']) if 'message' in json_data else print('None')")
  else
    message=$(echo $result | jq '.message')
  fi
  echo $message
}

function get_status {
  result=$(curl -s $worflow_status_url --header "authorization: token $GITHUB_USER_TOKEN")
  if [[ $no_py == "false" ]]
  then
    message=$(echo $result | python3 -c "import sys, json; json_data=json.load(sys.stdin); print(json_data['workflow_runs'][0]['status'])")
  else
    message=$(echo $result | jq '.workflow_runs | .[0] | .status')
  fi
  echo $message
}


function get_conclusion {
  if [[ $no_py == "false" ]]
  then
    conclusion=$(curl -s $worflow_status_url --header "authorization: token $GITHUB_USER_TOKEN" \
      | python3 -c "import sys, json; print(json.load(sys.stdin)['workflow_runs'][0]['conclusion'])")
  else
    conclusion=$(curl -s $worflow_status_url --header "authorization: token $GITHUB_USER_TOKEN" \
      | jq '.workflow_runs | .[0] | .conclusion')
  fi
  echo $conclusion
}

function check_status {
  message=$(get_message)
  if [[ "$message" == "API rate limit exceeded for"* ]]
  then
    echo "Limit of server requests exceeded. Wait some minutes an retry later."
    exit 1
  elif [[ "$message" == "Bad credentials"* ]]
  then
    echo "You are not authenticated. Token needed."
    exit 2
  else
    echo $(get_status)
    exit 0
  fi
}

function check_result {
  # check if the workflow failed or not, echo result return bool, 1 beeing failure, 0 success
  conclusion=$(get_conclusion)
  echo $conclusion
  while [[ "$conclusion" == "None" ]] && [ $currentwaits -lt $maxwaits ]
  do
    currentwaits=$(( currentwaits + 1 ))
    echo $conclusion
    echo "Waiting another 5 seconds to complete."
    sleep 5s
    conclusion=$(get_conclusion)
    conclusion=$?
  done
  echo
  if [[ "$conclusion" == "success" ]]
  then
    echo "###################################"
    echo "# Workflow successfully finished! #"
    echo "###################################"
    exit 0
  elif [[ "$conclusion" == "failure" ]]
  then
    echo "#######################"
    echo "# !!Workflow failed!! #"
    echo "#######################"
    exit 1
  else
    echo "####################################################"
    echo "# !!Workflow failed or something else went wrong!! #"
    echo "####################################################"
    exit 1
  fi
}

function wait_for_status {
  while [[ "$(check_status)" != "completed" ]] && [ $currentwaits -lt $maxwaits ]
  do
    # wait while there is one running
    currentwaits=$(( currentwaits + 1 ))
    echo "There seems to be a job running or qeued; wait ${seconds_2_wait_4_request} seconds to complete."
    sleep "${seconds_2_wait_4_request}s"
  done
  if [ $currentwaits -lt $maxwaits ]
  then
    return 0
  else
    return 1
  fi
}

##################### lets go ######################
echo "Starting transkribus import."
# check if there is a workflow already running
status=$(check_status)
status_of_status=$?
if [[ "$status_of_status" == "2" ]]
then
  echo "$status"
  exit 1
elif [[ "$status_of_status" == "1" ]]
then 
  echo "$status"
  exit 1
else
  if [[ "$status" != "completed" ]]
  then
    wait_for_status
    returnval=$?
    if [[ "$returnval" == "1" ]]
    then
      echo "Maxed retries, server seems to be busy. Try again later."
      exit 1
    fi
  fi
fi

# trigger new workflow
echo "requesting status"
status=$(curl -s --request POST \
  --url "https://api.github.com/repos/bundesverfassung-oesterreich/bv-entities/actions/workflows/$WORKFLOW_FILENAME/dispatches" \
  --header "Accept: application/vnd.github+json" \
  --header "authorization: token $GITHUB_USER_TOKEN" \
  --data '{"ref": "main"}')

# this echos curls status code on stdout if something went wrong or "post request successful" if curling worked. Could be logged to file.
# also binary exitcode is returned, can be checked via $?, 1 being error, 0 being success
# results can be checked here to: https://github.com/bundesverfassung-oesterreich/bv-entities/actions
if [ -n "$status" ]
then
  # exits, it the request starting the job itself failed
  echo "error"
  echo "$status"
  exit 1
else
  # curl-post worked, lets check the result 
  echo "Working on it!"
  echo "post request successful"
  #############################
  if [[ $no_py == "false" ]]
  then
    # check if python is there, we need it for json processing
    if [[ $(command -v python3 >/dev/null 2>&1 && echo "true") != "true" ]]
    then
      echo "No python3 interpreter found. Maybe create alias in system or replace the 'python3' command in this file with the one unsed on your system (eg. python2)"
      exit 1
    fi
  else
    if ! command -v jwq
    then 
      echo "jq was not found. Please install it via apt-get install jq"
      exit 1
    fi
  fi
  #############################
  # initial waiting for the job
  echo "Waiting for job to succeed, this might take a while."
  sleep $seconds_2_wait_4_request
  # check status of last job on server and wait, if it hasn't finished jet
  while [[ $(check_status) != "completed" ]] && [ $currentwaits -lt $maxwaits ]
  do
    currentwaits=$(( currentwaits + 1 ))
    echo "Waiting another ${seconds_2_wait_4_request} seconds to complete."
    sleep "${seconds_2_wait_4_request}s"
  done
  if [ $currentwaits -gt $maxwaits ]
  then
    echo "Maxed retries, try again later"
  fi
  # call function to check the overall result of the workflow run
  check_result
fi
exit 0
