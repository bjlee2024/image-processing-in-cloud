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
resource "aws_iam_role_policy_attachment" "pointcloud_cloudwatch_agent_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM role policy attachment for api.py
resource "aws_iam_role_policy_attachment" "pointcloud_s3_access_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM role policy attachment for SSM
resource "aws_iam_role_policy_attachment" "pointcloud_ec2_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.pointcloud_ec2_role.name
}

# IAM instance profile
resource "aws_iam_instance_profile" "pointcloud_ec2_profile" {
  name = "pointcloud_ec2_profile"
  role = aws_iam_role.pointcloud_ec2_role.name
}

# Security group for EC2 instances
resource "aws_security_group" "pointcloud_ec2_sg" {
  name        = "pointcloud_ec2_sg"
  description = "Security group for EC2 instances"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.pointcloud_alb_sg.id]
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
  depends_on = [aws_s3_bucket.image_processing_bucket]
  bucket     = var.s3_bucket_name
  key        = var.s3_key
  source     = "./ec2/api.py"
}

# Launch template
resource "aws_launch_template" "pointcloud_api_server" {
  name                   = "api_server_template"
  image_id               = var.custom_ami_id
  instance_type          = var.instance_type
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.pointcloud_ec2_sg.id]
  depends_on             = [aws_s3_object.api_py, aws_iam_instance_profile.pointcloud_ec2_profile]

  iam_instance_profile {
    name = aws_iam_instance_profile.pointcloud_ec2_profile.name
  }

  # block_device_mappings {
  #   device_name = "/dev/sda1"
  #   ebs {
  #     snapshot_id = var.custome_snap_id
  #     delete_on_termination = true
  #   }
  # } 

  user_data = base64encode(<<-EOF
              <powershell>
              Start-Transcript -Path C:\userdata_execution.log

              try {
                  # Function to check if a command exists
                  function Test-Command($cmdname) {
                      return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
                  }

                  # Check if Python is installed
                  if (-not (Test-Command python)) {
                      Write-Host "Python is not installed. Installing Python..."
                      
                      # Download Python installer
                      $pythonUrl = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"
                      $installerPath = "$env:TEMP\python-installer.exe"
                      Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath

                      # Install Python silently
                      Start-Process -FilePath $installerPath -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait
                      
                      # Remove the installer
                      Remove-Item -Path $installerPath -Force

                      # Refresh environment variables
                      $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                      Write-Host "Python has been installed."
                  } else {
                      Write-Host "Python is already installed."
                  }

                  # Install AWS Tools for PowerShell if not already installed
                  if (-not (Get-Module -ListAvailable -Name AWSPowerShell)) {
                      Install-Module -Name AWSPowerShell -Force -AllowClobber
                  }

                  Import-Module AWSPowerShell

                  # Configure CloudWatch agent
                  # $config = @{
                  #     logs = @{
                  #         logs_collected = @{
                  #             files = @{
                  #                 collect_list = @(
                  #                     @{
                  #                         file_path = "C:\MeditAutoTest\logs\*.log"
                  #                         log_group_name = "/ec2/api-server-logs"
                  #                         log_stream_name = "{instance_id}"
                  #                         timezone = "UTC"
                  #                     }
                  #                 )
                  #             }
                  #         }
                  #     }
                  # }
                  # $config | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 -FilePath "C:\cloudwatch-config.json"

                  # # Start CloudWatch agent
                  # & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -c file:"C:\cloudwatch-config.json" -s

                  # Download api.py from S3
                  $s3bucket = "${var.s3_bucket_name}"
                  $s3key = "${var.s3_key}"
                  Read-S3Object -BucketName $s3bucket -Key $s3key -File C:\MeditAutoTest\api.py

                  # Create a scheduled task to start the API server on system startup
                  $action = New-ScheduledTaskAction -Execute "python" -Argument "C:\MeditAutoTest\api.py"
                  $trigger = New-ScheduledTaskTrigger -AtStartup
                  $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                  Register-ScheduledTask -TaskName "StartAPIServer" -Action $action -Trigger $trigger -Principal $principal -Description "Start API server on system startup"

                  # Start the API server immediately
                  Start-ScheduledTask -TaskName "StartAPIServer"

                  Write-Host "User data script execution completed successfully."
              }
              catch {
                  Write-Host "An error occurred during user data script execution: $_"
                  $_ | Out-File -FilePath C:\userdata_error.log
              }
              finally {
                  Stop-Transcript
              }
              </powershell>
              EOF
  )
}

# Auto Scaling group
resource "aws_autoscaling_group" "pointcloud_api_server_asg" {
  name                = "api_server_asg"
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  target_group_arns   = [aws_lb_target_group.pointcloud_api_server_tg.arn]
  vpc_zone_identifier = var.subnet_ids
  depends_on          = [aws_launch_template.pointcloud_api_server]

  launch_template {
    id      = aws_launch_template.pointcloud_api_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "point-cloud-api"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "pointcloud_api_server_alb" {
  name               = "pointcloud-api-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.pointcloud_alb_sg.id]
  subnets            = var.subnet_ids
}

# ALB Security Group
resource "aws_security_group" "pointcloud_alb_sg" {
  name        = "pointcloud-alb_sg"
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
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

# ALB Target Group
resource "aws_lb_target_group" "pointcloud_api_server_tg" {
  name     = "pointcloud-api-server-tg"
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
resource "aws_lb_listener" "pointcloud_api_server_listener" {
  load_balancer_arn = aws_lb.pointcloud_api_server_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pointcloud_api_server_tg.arn
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
  cooldown               = 600
  autoscaling_group_name = aws_autoscaling_group.pointcloud_api_server_asg.name
}
