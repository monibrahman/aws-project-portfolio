# api_gateway.tf

# We're using an HTTP API (not the older "REST API" type) — it's simpler,
# cheaper (roughly 70% less per request), and covers everything a typical
# portfolio/backend project needs. REST APIs add features like request
# validation and API key management that are usually enterprise-specific.
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.environment}-api"
  protocol_type = "HTTP"
}

# --- Integration: connects API Gateway to our Lambda function ---
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
  # "AWS_PROXY" means API Gateway passes the raw request through to Lambda
  # and expects Lambda to return a properly-shaped response (which is why
  # our handler returns that specific statusCode/headers/body dict).
}

# --- Route: which incoming requests trigger the integration above ---
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# --- Stage: a named, deployed instance of the API (e.g. "prod", "dev") ---
# auto_deploy=true means every change to routes/integrations goes live
# immediately — fine for a portfolio project; larger teams often add a
# manual deployment step for production stages.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# --- Permission: allow API Gateway to actually invoke this Lambda ---
# This is easy to forget and a classic source of confusing 403 errors: the
# IAM role gives the Lambda permission to DO things, but a separate
# resource-based policy on the Lambda ITSELF has to explicitly allow API
# Gateway to invoke it in the first place.
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
