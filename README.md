# Overall Workflow

This repository contains a set of GitHub Actions workflows designed to automate the testing and deployment of the `spaceInvaders-source` project. The primary workflow is the nightly test, which runs every night at midnight (Pacific Time) and can also be triggered manually. The workflow involves creating a temporary EC2 instance, bundling the source code, deploying it to the EC2 instance, running smoke tests, and handling the results.

## Workflow Files

### `.github/workflows/nightly-test.yml`

This is the main workflow file that orchestrates the nightly test process.

**Jobs:**

1. **create-temp-ec2**
  - **Purpose**: Creates a temporary EC2 instance for running tests.
  - **Steps**:
    - Configure AWS credentials.
    - Create a temporary EC2 instance and retrieve its Instance ID and Public DNS.

2. **bundle-source-code**
  - **Purpose**: Bundles the source code into a tarball.
  - **Steps**:
    - Checkout the source code.
    - Set file permissions.
    - Archive the source code.
    - Upload the source code artifact.

3. **deploy-nightly-source-code**
  - **Purpose**: Deploys the bundled source code to the temporary EC2 instance and runs smoke tests.
  - **Steps**:
    - Checkout the repository.
    - Download the source code artifact.
    - Create an SSH key and known hosts directory.
    - Upload the source code to the EC2 instance.
    - Run smoke tests on the EC2 instance.

### `.github/workflows/shutdown-ec2.yml`

This workflow is triggered to shut down the EC2 instance after tests are completed.

**Jobs:**

1. **shutdown-ec2**
  - **Purpose**: Terminates the EC2 instance.
  - **Steps**:
    - Configure AWS credentials.
    - Terminate the EC2 instance using its Instance ID.

### `.github/workflows/trigger-test-failed.yml`

This workflow handles test failures by uploading the log file as an artifact.

**Jobs:**

1. **log-error**
  - **Purpose**: Processes and uploads the log file from failed tests.
  - **Steps**:
    - Decode and save the log file.
    - Upload the log file as an artifact.

### `.github/workflows/trigger-qa-deployment.yml`

This workflow deploys the application to the QA environment if tests pass.

**Jobs:**

1. **build-and-push-docker-images**
  - **Purpose**: Builds and pushes Docker images to Amazon ECR.
  - **Steps**:
    - Checkout the source code.
    - Log in to Amazon ECR.
    - Build and tag Docker images for the backend and frontend.
    - Push the Docker images to Amazon ECR.

2. **deploy**
  - **Purpose**: Deploys the Docker images to the QA environment.
  - **Steps**:
    - Create a temporary SSH key.
    - Configure AWS credentials.
    - Retrieve the public DNS of the QA EC2 instance.
    - Log in to Amazon ECR and deploy the Docker images to the EC2 instance.

## Test Scripts

### `cli/run-smoke-test.sh`

This script runs smoke tests on the EC2 instance. It installs dependencies, starts the application using Docker Compose, and runs tests. If tests fail, it triggers the `trigger-test-failed.yml` workflow. After tests are completed, it triggers the `shutdown-ec2.yml` workflow to terminate the EC2 instance.
