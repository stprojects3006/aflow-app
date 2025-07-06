output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.k6_repo.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.k6_cluster.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.k6_cluster.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.k6_task.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.k6_vpc.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.k6_public_subnet.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.k6_sg.id
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.k6_logs.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for results"
  value       = aws_s3_bucket.k6_results.bucket
}

output "s3_bucket_url" {
  description = "URL of the S3 bucket"
  value       = "https://s3.${var.aws_region}.amazonaws.com/${aws_s3_bucket.k6_results.bucket}"
}

output "s3_results_path" {
  description = "S3 path where test results will be stored"
  value       = "s3://${aws_s3_bucket.k6_results.bucket}/test-results/"
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.k6_dashboard.dashboard_name}"
}

output "deployment_instructions" {
  description = "Instructions for deploying and running tests"
  value = <<-EOT
    ========================================
    K6 Load Testing Infrastructure Deployed
    ========================================
    
    Next Steps:
    
    1. Build and push Docker image:
       docker build -t ${aws_ecr_repository.k6_repo.repository_url}:latest ./docker
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.k6_repo.repository_url}
       docker push ${aws_ecr_repository.k6_repo.repository_url}:latest
    
    2. Run load test:
       aws ecs run-task \
         --cluster ${aws_ecs_cluster.k6_cluster.name} \
         --task-definition ${aws_ecs_task_definition.k6_task.family} \
         --launch-type FARGATE \
         --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.k6_public_subnet.id}],securityGroups=[${aws_security_group.k6_sg.id}],assignPublicIp=ENABLED}"
    
    3. Monitor results:
       - CloudWatch Dashboard: ${aws_cloudwatch_dashboard.k6_dashboard.dashboard_name}
       - CloudWatch Logs: ${aws_cloudwatch_log_group.k6_logs.name}
       - S3 Results: ${aws_s3_bucket.k6_results.bucket}
    
    4. View logs:
       aws logs tail ${aws_cloudwatch_log_group.k6_logs.name} --follow
    
    ========================================
  EOT
} 