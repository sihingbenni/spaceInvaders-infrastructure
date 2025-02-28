#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <instance_id> <github_secret_token>"
  exit 1
fi

INSTANCE_ID=$1
GITHUB_TOKEN=$2

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

  # Trigger QA deployment workflow
  curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/trigger-qa-deployment.yml/dispatches \
    -d "{\"ref\":\"main\"}"

else
  echo "Tests failed with exit code $TEST_EXIT_CODE."
  exit $TEST_EXIT_CODE
fi

# Trigger shutdown EC2 workflow
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/sihingbenni/spaceInvaders-infrastructure/actions/workflows/shutdown-ec2.yml/dispatches \
  -d "{\"ref\":\"main\", \"inputs\": {\"instance_id\": \"$INSTANCE_ID\"}}"