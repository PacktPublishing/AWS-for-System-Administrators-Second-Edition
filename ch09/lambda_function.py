import urllib3
import json
import os

http = urllib3.PoolManager()

SLACK_HOOK = os.environ.get(“SLACK_WEBHOOK”, None)
SLACK_CHANNEL = os.environ.get(“SLACK_CHANNEL”, None)

if not SLACK_HOOK or not SLACK_CHANNEL:
    raise Exception(“Missing Slack hook or slack channel”)

def lambda_handler(event, context):
    url = SLACK_HOOK
                msg = {
                        "channel": SLACK_CHANNEL,
                        "username": "WEBHOOK_USERNAME",
                        "text": event["Records"][0]["Sns"]["Message"],
                        "icon_emoji": "",
                        }

                encoded_msg = json.dumps(msg).encode("utf-8")
                        resp = http.request("POST", url, body=encoded_msg)
                            print(
                                    {
                                        "message": event["Records"][0]["Sns"]["Message"],
                                        "status_code": resp.status,
                                        "response": resp.data,
                                        }
                                    )

