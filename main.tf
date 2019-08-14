provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_s3_bucket" "bucket" {
	force_destroy = "true"
}

resource "aws_config_config_rule" "rule" {
	name = "config-rule-${random_id.id.hex}"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

	scope {
		compliance_resource_id = aws_s3_bucket.bucket.id
		compliance_resource_types = ["AWS::S3::Bucket"]
	}
}

resource "aws_cloudwatch_event_rule" "compliance_change" {

  event_pattern = <<PATTERN
{
  "source": [
    "aws.config"
  ],
  "detail-type": [
    "Config Rules Compliance Change"
  ],
  "detail": {
    "configRuleARN": [
      "${aws_config_config_rule.rule.arn}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "sqs" {
  rule      = "${aws_cloudwatch_event_rule.compliance_change.name}"
  target_id = "SQS"
  arn       = "${aws_sqs_queue.queue.arn}"
	sqs_target {
		message_group_id = "1"
	}
}

resource "aws_sqs_queue" "queue" {
	name = "queue-${random_id.id.hex}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_sqs_queue_policy" "test" {
  queue_url = "${aws_sqs_queue.queue.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Effect": "Allow",
			"Principal": {
				 "Service": "events.amazonaws.com"
			},
			"Action": "sqs:SendMessage",
			"Resource": "${aws_sqs_queue.queue.arn}",
			"Condition": {
				"ArnEquals": {
					"aws:SourceArn": "${aws_cloudwatch_event_rule.compliance_change.arn}"
				}
			}
		}
	]
}
POLICY
}

output "bucket" {
	value = aws_s3_bucket.bucket.id
}

output "queue" {
	value = aws_sqs_queue.queue.id
}
