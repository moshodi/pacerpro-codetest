import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

INSTANCE_ID = os.environ['INSTANCE_ID']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


## Initialize EC2 and SNS boto3 clients
ec2_client = boto3.client('ec2')
sns_client = boto3.client('sns')


def lambda_handler(event, context):
    logger.info("Triggered by event: %s", event)
    try:
        logger.info("Rebooting EC2 instance: %s", INSTANCE_ID)
        ec2_client.reboot_instances(InstanceIds=[INSTANCE_ID])
        logger.info("Successful Reboot of instance %s", INSTANCE_ID)
        notification_message = (
            f"EC2 instance {INSTANCE_ID} successfully rebooted."
            "In response to sumo alert"
        )
        logger.info("Sending notification to SNS topic %s", SNS_TOPIC_ARN)
        sns_client.publish(
            TopicARN=SNS_TOPIC_ARN,
            Message=notification_message,
            Subject="EC2 Instnace Reboot Notification"
        )
        logger.info("Successfully sent notification to the SNS topic %s", SNS_TOPIC_ARN)

        return dict(
            status_code=200,
            body=f"rebooted instance {INSTANCE_ID} and sent notifications to SNS topic {SNS_TOPIC_ARN}"
        )
    except Exception as e:
        logger.exception("Error rebooting instance %s:", INSTANCE_ID)
        raise
