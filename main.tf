# main.tf

provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

# IAM role for EC2 instances
resource "aws_iam_role" "pointcloud_ec2_role" {
  name = "pointcloud_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role policy attachment for CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM role policy attachment for api.py
resource "aws_iam_role_policy_attachment" "s3_access_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM role policy attachment for SSM
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM instance profile
resource "aws_iam_instance_profile" "pointcloud_ec2_profile" {
  name = "pointcloud_ec2_profile"
  role = aws_iam_role.pointcloud_ec2_role.name
}

# Security group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Security group for EC2 instances"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 Bucket
resource "aws_s3_bucket" "image_processing_bucket" {
  bucket = var.s3_bucket_name
}

# Upload api.py to S3
resource "aws_s3_object" "api_py" {
    depends_on = [ aws_s3_bucket.image_processing_bucket ]
  bucket = var.s3_bucket_name
  key    = var.s3_key
  source = "./ec2/api.py"
}

# Launch template
resource "aws_launch_template" "api_server" {
  name                   = "api_server_template"
  image_id               = var.custom_ami_id
  instance_type          = var.instance_type
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.pointcloud_ec2_profile.name
  }

  user_data = base64encode(<<-EOF
              <powershell>
              # Install CloudWatch agent
              $cloudwatch_agent_url = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
              Invoke-WebRequest -Uri $cloudwatch_agent_url -OutFile "C:\amazon-cloudwatch-agent.msi"
              Start-Process msiexec.exe -Wait -ArgumentList '/i C:\amazon-cloudwatch-agent.msi /qn'

              # Configure CloudWatch agent
              $config = @{
                  logs = @{
                      logs_collected = @{
                          files = @{
                              collect_list = @(
                                  @{
                                      file_path = "C:\\MeditAutoTest\\logs\\*.log"
                                      log_group_name = "/ec2/api-server-logs"
                                      log_stream_name = "{instance_id}"
                                      timezone = "UTC"
                                  }
                              )
                          }
                      }
                  }
              }
              $config | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 -FilePath "C:\cloudwatch-config.json"

              # Start CloudWatch agent
              & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -c file:"C:\cloudwatch-config.json" -s
              
              # Download and extract the code
              $s3bucket = "${var.s3_bucket_name}"
              $s3key    = "${var.s3_key}"
              #(New-Object -TypeName System.Net.WebClient).DownloadFile("XXXXXXXXXXXXXXXXXXXXXXXXX$s3bucket/$s3key", "C:\MeditAutoTest.zip")
              Read-S3Object -BucketName $s3bucket -Key $s3key -File C:\MeditAutoTest\api.py

              # Start the API server
              Start-Process python -ArgumentList "C:\MeditAutoTest\api.py"
              </powershell>
              EOF
  )
}

# Auto Scaling group
resource "aws_autoscaling_group" "api_server_asg" {
  name                = "api_server_asg"
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  target_group_arns   = [aws_lb_target_group.api_server_tg.arn]
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.api_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "API Server"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "api_server_alb" {
  name               = "api-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB Target Group
resource "aws_lb_target_group" "api_server_tg" {
  name     = "api-server-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/status/health"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# ALB Listener
resource "aws_lb_listener" "api_server_listener" {
  load_balancer_arn = aws_lb.api_server_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_server_tg.arn
  }
}

# CloudWatch Metric Alarm for scaling
resource "aws_cloudwatch_metric_alarm" "high_processing_time" {
  alarm_name          = "high-processing-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ProcessingDuration"
  namespace           = "CustomMetrics"
  period              = "60"
  statistic           = "Average"
  threshold           = var.processing_time_threshold
  alarm_description   = "This metric monitors processing time"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.api_server_asg.name
}
