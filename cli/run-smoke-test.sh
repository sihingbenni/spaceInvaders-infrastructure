#!/bin/bash

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

# create environment variable for the game url
export GAME_URL="localhost:8080"

# Run tests
npm run test
TEST_EXIT_CODE=$?

# Check if tests were successful
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo "Tests passed successfully."
else
  echo "Tests failed with exit code $TEST_EXIT_CODE."
  exit $TEST_EXIT_CODE
fi


