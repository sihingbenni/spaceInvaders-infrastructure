#!/bin/bash

npm install

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


