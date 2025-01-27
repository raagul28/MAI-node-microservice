provider "aws" {
  region = var.aws_region # The region will come from variables.tf
}
# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Create a Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Subnets with the Public Route Table
resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

# Get AWS Availability Zones dynamically
data "aws_availability_zones" "available" {
  state = "available"
}
# Create a Security Group for ECS tasks
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  # Allow inbound traffic on port 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}
# Create an ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "node-microservice-cluster"

  tags = {
    Name = "ecs-cluster"
  }
}
# Create an IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

# Attach ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach ECR Read-Only Policy
resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_ecs_task_definition" "ecs_task" {
  family                = "node-microservice-task"
  requires_compatibilities = ["FARGATE"]
  network_mode          = "awsvpc"
  cpu                   = "512"     # Increase from 256 to 512 (0.5 vCPU)
  memory                = "1024"    # Increase from 512 to 1024 MB
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "node-microservice"
      image     = "881490134638.dkr.ecr.us-east-1.amazonaws.com/node-microservice:latest"
      essential = true
      cpu       = 512      # Match the increased task-level CPU
      memory    = 1024     # Match the increased task-level memory
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "PORT"
          value = "3000"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/node-microservice"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}



# Update ECS Service to Attach to Target Group
resource "aws_ecs_service" "ecs_service" {
  name            = "node-microservice-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "node-microservice"
    container_port   = 3000
  }

  tags = {
    Name = "node-microservice-service"
  }
}
# Create an ALB
resource "aws_lb" "ecs_alb" {
  name               = "node-microservice-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id] # Use your ECS security group
  subnets            = aws_subnet.public[*].id        # Public subnets for the ALB

  enable_deletion_protection = false
}

# Create a Target Group for the ECS Service
resource "aws_lb_target_group" "ecs_tg" {
  name        = "node-microservice-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Create an ALB Listener
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

