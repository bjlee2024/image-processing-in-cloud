# API server provides the following endpoints with ALB DNS name
# http://{ALB_DNS_NAME}/status/health
# http://{ALB_DNS_NAME}/jobs
# http://{ALB_DNS_NAME}/job/{job_id}
# http://{ALB_DNS_NAME}/process 
output "api_server_alb_dns_name" {
  value = aws_lb.pointcloud_api_server_alb.dns_name
}

output "pointcloud_api_server_alb_dns_name" {
  value = aws_lb.pointcloud_api_server_alb.dns_name
}

output "image_processing_bucket" {
  value = aws_s3_bucket.image_processing_bucket.bucket
}

# output "pointcloud_cloudwatch_log_group" {
#   value = aws_cloudwatch_log_group.pointcloud_cloudwatch_log_group.name
# }
