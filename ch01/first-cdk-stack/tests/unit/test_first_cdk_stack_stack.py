import aws_cdk as core
import aws_cdk.assertions as assertions

from first_cdk_stack.first_cdk_stack_stack import FirstCdkStackStack

# example tests. To run these tests, uncomment this file along with the example
# resource in first_cdk_stack/first_cdk_stack_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = FirstCdkStackStack(app, "first-cdk-stack")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
