# Introduction

This document describes the steps to install the demonstration of Saga - Choreography pattern.

> All instructions in this repository have been tested on Mac OS Catalina (10.15.7).

- [Introduction](#introduction)
  - [Pre-requisites](#pre-requisites)
    - [Tools](#tools)
    - [Environment variables](#environment-variables)
  - [Installation](#installation)

## Pre-requisites

An AWS account with full admininstrator access - _not_ the root account - should be used. Further, the following tools should be installed and the environment variables should be configured.

### Tools

The following CLI tools should be installed on the workstation.

1. CLI tools
   1. `git`
   2. `curl`
   3. `aws`
   4. `mysql`
   5. `docker`
   6. `kubectl`
   7. `eksctl`
   8. `helm`
   9. `jq`

**Notes**

1. `aws` CLI should be configured with the user with full administrator access.

### Environment variables

The following environment variables will be referenced regularly in various repositories. Configuring them before hand will simplify the overall procedure.

```bash
# Set the AWS region ID where this demo will be run e.g. ap-south-1
export REGION_ID=ap-south-1
# Set the AWS acouunt ID where this demo will be run e.g. 123456789012
export ACCOUNT_ID=123456789012
# Set the URL of the `git` repo where this code is hosted e.g. Amazon Code Commit
export GIT_URL=ssh://git-codecommit.ap-south-1.amazonaws.com/v1/repos
```

## Installation

To install various projects for the Saga Choreography pattern, follow the instructions of each repository as listed below _and in that order._

| Repository           | Remarks                                   |
| -------------------- | ----------------------------------------- |
| `eks-saga-aws`       | AWS IAM, SQS, SNS and Amazon ECR objects. |
| `eks-saga-db`        | AWS RDS (MySQL) database.                 |
| `eks-saga-cluster`   | Amazon EKS cluster.                       |
| `eks-saga-orders`    | Orders microservice.                      |
| `eks-saga-ordersrb`  | Orders rollback microservice.             |
| `eks-saga-inventory` | Inventory microservice.                   |
| `eks-saga-audit`     | Audit microservice.                       |
| `eks-saga-trail`     | Trail microservice.                       |

