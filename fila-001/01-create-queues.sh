#!/usr/bin/env bash
# Roda automaticamente quando o LocalStack fica READY.
# Troque os nomes pelos das filas reais dos projetos.

set -euo pipefail

awslocal sqs create-queue --queue-name minha-fila-dlq

awslocal sqs create-queue \
  --queue-name minha-fila \
  --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:000000000000:minha-fila-dlq\",\"maxReceiveCount\":\"5\"}"
  }'

echo "filas criadas:"
awslocal sqs list-queues
