#!/usr/bin/env bash
# Roda quando o LocalStack fica READY. Cria SQS + DynamoDB que os apps esperam.
# Região sa-east-1 (mesma do dev). Ajuste schema conforme o item real do historic.
set -euo pipefail

REGION="sa-east-1"

# ---- SQS (historic: DATAMESH_QUEUE_URL) ----
awslocal sqs create-queue --region "$REGION" --queue-name datamesh-queue-dlq
awslocal sqs create-queue --region "$REGION" \
  --queue-name datamesh-queue \
  --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:sa-east-1:000000000000:datamesh-queue-dlq\",\"maxReceiveCount\":\"5\"}"
  }'

# ---- DynamoDB (historic: DYNAMODB_MESSAGE_TABLE_NAME) ----
# SCHEMA É PLACEHOLDER: confirme a chave real (PK/SK) no historic (tags dynamodbav).
awslocal dynamodb create-table --region "$REGION" \
  --table-name tbum3007_mens_central \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo "recursos criados:"
awslocal sqs list-queues --region "$REGION"
awslocal dynamodb list-tables --region "$REGION"