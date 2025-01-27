output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}
output "security_group_id" {
  value = aws_security_group.ecs_sg.id
}
output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}
output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.ecs_task.arn
}
output "ecs_service_name" {
  value = aws_ecs_service.ecs_service.name
}
