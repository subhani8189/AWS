variable "raw_bucket_id" {}
variable "raw_bucket_arn" {}
variable "processed_bucket_id" {}
variable "processed_bucket_arn" {}
variable "notification_email" {}

# --- 1. IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_role" {
  name = "pipeline_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

# Attach basic logging and S3 access
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["s3:GetObject"], Effect = "Allow", Resource = "${var.raw_bucket_arn}/*" },
      { Action = ["s3:PutObject", "s3:GetObject"], Effect = "Allow", Resource = "${var.processed_bucket_arn}/*" },
      { Action = ["s3:ListBucket"], Effect = "Allow", Resource = "*" },
      { Action = ["sns:Publish"], Effect = "Allow", Resource = "*" }
    ]
  })
}

# --- 2. Processor Lambda (Triggered by Upload) ---
data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = "${path.root}/src/processor.py"
  output_path = "${path.root}/processor.zip"
}

resource "aws_lambda_function" "processor" {
  filename      = data.archive_file.processor_zip.output_path
  function_name = "DataProcessor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "processor.lambda_handler"
  runtime       = "python3.9"
  source_code_hash = data.archive_file.processor_zip.output_base64sha256
  environment {
    variables = { PROCESSED_BUCKET = var.processed_bucket_id }
  }
}

# S3 Trigger Permission
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.raw_bucket_arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.raw_bucket_id
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

# --- 3. Reporter Lambda (Triggered by Schedule) ---
data "archive_file" "reporter_zip" {
  type        = "zip"
  source_file = "${path.root}/src/reporter.py"
  output_path = "${path.root}/reporter.zip"
}

resource "aws_lambda_function" "reporter" {
  filename      = data.archive_file.reporter_zip.output_path
  function_name = "DailyReporter"
  role          = aws_iam_role.lambda_role.arn
  handler       = "reporter.lambda_handler"
  runtime       = "python3.9"
  source_code_hash = data.archive_file.reporter_zip.output_base64sha256
  environment {
    variables = { 
      PROCESSED_BUCKET = var.processed_bucket_id 
      SNS_TOPIC_ARN = aws_sns_topic.daily_report.arn
    }
  }
}

# SNS Topic for Email
resource "aws_sns_topic" "daily_report" {
  name = "daily-data-report"
}

resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.daily_report.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# EventBridge Schedule (9:00 AM UTC)
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-report-trigger"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "SendReport"
  arn       = aws_lambda_function.reporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}