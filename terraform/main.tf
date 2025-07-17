# Configure a provider

provider = "aws" {
    region = var.aws_region
}

# Fetching the AWS ACCOUNT ID (configured via AWS CLI) to construct ARNS with the resources

data "aws_caller_identity" "current" {}

# Create SNS topic

resource "aws_sns_topic" "alert_topic" {
    name = "sumo-logic-alert_topic"
}

# Provision EC2

resource "aws_instance" "app_server" {
    ami             = var.ami.id
    instance_type   = var.instance_type
    tags = {
        Name = "AppServer"
    }
}

# Define IAM role with trust policy so lambda can assume it

data "aws_iam_policy_document" "lambda_assume" {
    statement {
        effect      = "Allow"
        actions     = ["sts: AssumeRole"]
        principals {
            type - "Service"
            identifiers = ["lambda.amazonaws.com"]
        } 
    }   
}

resource "aws_iam_role" "lambda_exec" {
    name                    = "sumo-logic-lambda-role"
    assume_role_policy      = data.aws_iam_policy_document
}

# Crafting least priveledge inline policy for lambda
# - Reboot Ec2 instance
# - Publish only to the SNS topic
# - Write logs to CloudWatch

data "aws_iam_policy_document" "lambda_policy" {
    statement {
        sid             = "AllowRebootInstance"
        effect          = "Allow"
        actions         = ["ec2:RebootInstances]
        resources = [
            arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current_account_id}/${aws}
        ]
    }
    
    statement {
        sid             = "AllowPublishDNS"
        effect          = "Allow"
        actions         = ["sns:Publish"]
        resources       = [aws_sns_topic.alert_topic.arn]
    }

    statement {
        sid             = "AllowLog"
        effect          = "Allow"
        actions         = {
            "log:CreateLogGroup",
            "log:CreateLogStream",
            "log:PollingEvents",
        }
        resources =  [
            arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current_account_id}/${aws}
        ]
    }
}

resource "aws_iam_role_policy" "lambda_policy_attach" {
    name        = "sumo-logic-lambda-policy"
    role        = aws.aws_iam_role_policy.lambda_exec.id
    policy      = data.aws_iam_policy_document.lambda_policy.json
}

# bundle the local lambda function directory into a zip for deployment

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "${path.module}/lambda_function"
    output_path = "${path.module}/lambda_function.zip"
}

# Deploying the lambda function

resource "aws_lambda_function" "reboot_handler" {
    function_name       = "sumo-logic-reboot-handler"
    runtime             = "python3.10"
    handler             = "lambda_function.lambda_handler"
    role                = aws_iam_role.lambda_exec.arn
    filename            = data.archive_file.lambda_ip.output_path
    source_code_hash    = data.archive_file.lambda_zip.output_base64sha256

    envirnment {
        variables = {
            INSTANCE_ID = aws_instance.app_server.id
            SNS_TOPIC_ARN = aws_sns_topic.alert_topic.arn
        }
    } 
}


# Output key values to wire up Sumo logic alert and verify resources

output "sns_topic_arn" {
    description = "SNS topic ARN for alert notifications"
    value       = aws_sns_topic.alert_topic.arn
}

output "lambda_function_name" {
    description = "Name of reboot lamdbda function"
    value       = aws_lambda_function.reboot_handler.function_name
}

output "ec2_instance_id" {
    description = "EC2 instance target for the reboot"
    value       = aws_instance.app_server.id
}


# define variables

variable "aws_region" {
    description = "AWS region to deploy"
    type        = string
    default     = "us-west-3"
}

variable "ami_id" {
    description = "AMI ID for the EC2 instance"
    type        = string
}

variable "instance_type" {
    description = "AWS instance size"
    type        = string
    default     = "t3.micro"
}
