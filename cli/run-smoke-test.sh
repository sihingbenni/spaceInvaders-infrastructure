#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <instance_id> <github_secret_token>"
  exit 1
fi

# Function to trigger the shutdown EC2 workflow
trigger_shutdown_ec2_workflow() {
  local instance_id=$1
  local github_token=$2
  echo "Triggering shutdown EC2 workflow for instance $instance_id" >> $LOG_FILE 2>&1
  curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $github_token" \
    https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/shutdown-ec2.yml/dispatches \
    -d "{\"ref\":\"main\", \"inputs\": {\"instance_id\": \"$instance_id\"}}"
}

# Function to trigger the QA deployment workflow
trigger_qa_deployment() {
  local github_token=$1

  echo "Triggering QA deployment workflow" >> $LOG_FILE 2>&1

  curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $github_token" \
    https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/trigger-qa-deployment.yml/dispatches \
    -d "{\"ref\":\"main\"}"
}

trigger_test_failed() {
  local github_token=$1
  local log_file=$2

  echo "Triggering test failed workflow" >> $LOG_FILE 2>&1

  log_content=$(cat "$log_file" | base64 | tr -d '\n')
  curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $github_token" \
    https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/trigger-test-failed.yml/dispatches \
    -d "{\"ref\":\"main\", \"inputs\": {\"log\": \"$log_content\"}}"
}

INSTANCE_ID=$1
GITHUB_TOKEN=$2

# Log file
LOG_FILE="run-smoke-test.log"

{
  # Install dependencies
  npm install

  # Start the application
  docker compose -f test.docker-compose.yml up -d

  # Wait until the container space_invaders is healthy, with a maximum of 10 attempts
  attempt_counter=0
  max_attempts=60

  while [ "$(docker inspect -f '{{.State.Health.Status}}' spaceinvaders-space_invaders_frontend-1)" != "healthy" ]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
      echo "Max attempts reached, container is not healthy."

      # Trigger shutdown EC2 workflow
      trigger_shutdown_ec2_workflow "$INSTANCE_ID" "$GITHUB_TOKEN"
      exit 1
    fi

    attempt_counter=$((attempt_counter+1))
    sleep 1
  done

  # Create environment variable for the game URL
  export GAME_URL="http://localhost:8080"

  # Run tests
  npm run test
  TEST_EXIT_CODE=$?

  # Check if tests were successful
  if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "Tests passed successfully."
    trigger_qa_deployment "$GITHUB_TOKEN"
  else
    echo "Tests failed with exit code $TEST_EXIT_CODE."
    trigger_test_failed "$GITHUB_TOKEN" "$LOG_FILE"
  fi
} >> $LOG_FILE 2>&1

# if test failed send the contents of the log file to the test failed workflow
if [ $TEST_EXIT_CODE -ne 0 ]; then
  trigger_test_failed "$GITHUB_TOKEN" "$LOG_FILE"
fi

trigger_shutdown_ec2_workflow "$INSTANCE_ID" "$GITHUB_TOKEN"