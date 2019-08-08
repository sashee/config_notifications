# config_notifications

* terraform init
* terraform apply

### Monitor notifications

```
while sleep 1; do (MSG=$(aws sqs receive-message --queue-url $(terraform output queue)); [ ! -z "$MSG" ] && echo "$MSG" | jq -r '.Messages[] | .ReceiptHandle' | (xargs -I {} aws sqs delete-message --queue-url $(terraform output queue) --receipt-handle {}) && echo "$MSG") | jq -r '.Messages[] | .Body | fromjson | "\(.time): \(.detail.resourceId) => \(.detail.newEvaluationResult.complianceType)"'; done
```

### Change compliance status (requires 3-5 minutes to show up)

```
aws s3api get-bucket-encryption --bucket $(terraform output bucket) && aws s3api delete-bucket-encryption --bucket $(terraform output bucket) || aws s3api put-bucket-encryption --bucket $(terraform output bucket) --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
```
