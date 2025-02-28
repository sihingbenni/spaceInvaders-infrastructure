#!/bin/bash

# Install dependencies
npm install

# Start the application
docker compose up -d

# Wait until the container space_invaders is healthy
while [ "$(docker inspect -f '{{.State.Health.Status}}' spaceinvaders-space_invaders-1)" != "healthy" ]; do
  sleep 1
done

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


