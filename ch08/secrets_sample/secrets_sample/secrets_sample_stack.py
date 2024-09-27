import os
import json

from aws_cdk import (
    Duration,
    Stack,
    # aws_sqs as sqs,
    aws_secretsmanager as sm,
    aws_lambda as lambda_,
)

from constructs import Construct

class SecretsSampleStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        gen_config = {
            "secret_string_template": json.dumps({"Username": "admin"}),
            "generate_string_key": "Password"
        }

        secret = sm.Secret(self, "ExampleSecret",
            generate_secret_string=gen_config
        )

        current_dir = os.path.dirname(os.path.abspath(__file__))
        lambda_code_path = os.path.join(current_dir, "..", "src", "get_secret_func")

        func = lambda_.Function(self, "RetrieveFunction",
            function_name="GetSecretFunc",
            code=lambda_.Code.from_asset(lambda_code_path),
            handler="func.handler",
            runtime=lambda_.Runtime.PYTHON_3_11,
            environment={
                "SECRET_ARN": secret.secret_arn
            },
            timeout=Duration.seconds(10)
        )
        secret.grant_read(func)
