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

  curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $github_token" \
    https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/shutdown-ec2.yml/dispatches \
    -d "{\"ref\":\"main\", \"inputs\": {\"instance_id\": \"$instance_id\"}}"
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

  while [ "$(docker inspect -f '{{.State.Health.Status}}' spaceinvaders-space_invaders-1)" != "healthy" ]; do
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
    trigger_shutdown_ec2_workflow "$INSTANCE_ID" "$GITHUB_TOKEN"
    exit 0
  else
    echo "Tests failed with exit code $TEST_EXIT_CODE."
    trigger_shutdown_ec2_workflow "$INSTANCE_ID" "$GITHUB_TOKEN"
    exit $TEST_EXIT_CODE
  fi
} >> $LOG_FILE 2>&1