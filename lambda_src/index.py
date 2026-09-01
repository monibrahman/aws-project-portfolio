import json
import os


def handler(event, context):
    """
    A minimal Lambda handler behind API Gateway.

    'event' contains details about the incoming HTTP request (path, method,
    headers, body, etc). 'context' carries runtime info (request ID, time
    remaining before timeout, etc) — we don't need either in depth yet.

    Returning a dict with statusCode/body in this shape is required for API
    Gateway's Lambda "proxy integration" to correctly translate this into
    an HTTP response.
    """
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Hello from Lambda, running inside a VPC",
                "environment": os.environ.get("ENVIRONMENT", "unknown"),
            }
        ),
    }
