# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "game-price-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Route 53 health check — pings the site every 30s
resource "aws_route53_health_check" "web" {
  fqdn              = var.domain
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "game-price-web"
  }
}

# CloudWatch alarm — fires when health check fails
resource "aws_cloudwatch_metric_alarm" "web_down" {
  alarm_name          = "game-price-web-down"
  alarm_description   = "Site is not responding"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.web.id
  }
}
