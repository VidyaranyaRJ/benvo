output "subnet_id" {
  value = aws_subnet.my_subnet.id
}

output "subnet_id_2" {
  value = aws_subnet.my_subnet_2.id
}

output "security_group_id" {
  value = aws_security_group.ecs_security_group.id
}

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}