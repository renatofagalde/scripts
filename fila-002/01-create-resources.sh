#!/usr/bin/env bash
# Roda quando o LocalStack fica READY. Cria SQS + DynamoDB que os apps esperam.
# Ajuste nomes/schema conforme o infra/*.tf real de cada repo.
set -euo pipefail

# ---- SQS (historic: DATAMESH_QUEUE_URL) ----
awslocal sqs create-queue --queue-name datamesh-queue-dlq
awslocal sqs create-queue \
  --queue-name datamesh-queue \
  --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:000000000000:datamesh-queue-dlq\",\"maxReceiveCount\":\"5\"}"
  }'

# ---- DynamoDB (wshandler: AWS_DYNAMODB_TABLE / historic: DYNAMODB_MESSAGE_TABLE_NAME) ----
# SCHEMA É PLACEHOLDER: confira a chave real (PK/SK) no infra/*.tf antes de usar.
awslocal dynamodb create-table \
  --table-name um3-messages \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo "recursos criados:"
awslocal sqs list-queues
awslocal dynamodb list-tables
