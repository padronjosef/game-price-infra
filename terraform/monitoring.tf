# --- IAM Role for CloudWatch Agent ---

resource "aws_iam_role" "ec2_cloudwatch" {
  name = "nukaloot-ec2-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "nukaloot-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch.name
}

# --- SNS Topic for Alerts ---

resource "aws_sns_topic" "alerts" {
  name = "nukaloot-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CPU Alarm (native EC2 metric, no agent needed) ---

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "nukaloot-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU > 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

# --- Disk Alarm (requires CloudWatch Agent) ---

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "nukaloot-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  alarm_description   = "Disk usage > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
    path       = "/"
    device     = "nvme0n1p1"
    fstype     = "ext4"
  }
}

# --- Memory Alarm (requires CloudWatch Agent) ---

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "nukaloot-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory usage > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

# --- CloudWatch Dashboard ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "nukaloot"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization (%)"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app.id, { stat = "Average" }]
          ]
          period = 300
          yAxis  = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [{ value = 80, label = "Alarm threshold", color = "#d62728" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Memory Used (%)"
          region = var.aws_region
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", aws_instance.app.id, { stat = "Average" }]
          ]
          period = 300
          yAxis  = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [{ value = 80, label = "Alarm threshold", color = "#d62728" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Disk Used (%)"
          region = var.aws_region
          metrics = [
            ["CWAgent", "disk_used_percent", "InstanceId", aws_instance.app.id, "path", "/", "device", "nvme0n1p1", "fstype", "ext4", { stat = "Maximum" }]
          ]
          period = 300
          yAxis  = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [{ value = 80, label = "Alarm threshold", color = "#d62728" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Network Traffic (bytes)"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.app.id, { stat = "Sum", label = "In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.app.id, { stat = "Sum", label = "Out" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Status Checks"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.app.id, { stat = "Maximum", label = "Any Failed" }],
            ["AWS/EC2", "StatusCheckFailed_Instance", "InstanceId", aws_instance.app.id, { stat = "Maximum", label = "Instance" }],
            ["AWS/EC2", "StatusCheckFailed_System", "InstanceId", aws_instance.app.id, { stat = "Maximum", label = "System" }]
          ]
          period = 300
          yAxis  = { left = { min = 0, max = 1 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "CPU Credit Balance"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUCreditBalance", "InstanceId", aws_instance.app.id, { stat = "Average" }],
            ["AWS/EC2", "CPUCreditUsage", "InstanceId", aws_instance.app.id, { stat = "Average" }]
          ]
          period = 300
        }
      }
    ]
  })
}
