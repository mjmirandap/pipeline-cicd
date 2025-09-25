
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-2" 
}

resource "random_id" "suffix" {
  byte_length = 2
}



resource "aws_security_group" "pipelinecicd_sg" {
  name        = "pipelinecicd-sg-${var.run_id}"
  description = "SG compartido para el ALB y las tareas de Fargate"
  vpc_id      = var.vpc_id 

  ingress {
    description = "Allow HTTP access"
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

# 1. Cluster de ECS para el ambiente
resource "aws_ecs_cluster" "pipelinecicd_cluster" {
  name = "pipelinecicd-cluster-${var.run_id}"
}

# 2. Target Group para el ALB
resource "aws_lb_target_group" "pipelinecicd_tg" {
  name        = "pipelinecicd-tg-${var.run_id}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

# 3. Task definition (CON EL ROL DE EJECUCION Y LOGS)
resource "aws_ecs_task_definition" "pipelinecicd_task" {
  family                   = "pipelinecicd-task-${var.run_id}"
  
  container_definitions    = jsonencode([
    {
      "name"      = "pipelinecicd-container",
      "image"     = "${var.ecr_url}:${var.image_tag}",
      "cpu"       = 256,
      "memory"    = 512,
      "essential" = true,
      "portMappings" = [
        {
          "containerPort" = 80,
          "hostPort"      = 80
        }
      ],
      "logConfiguration" : { 
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/pipeline-cicd",
          "awslogs-region" : "us-east-2",
          "awslogs-stream-prefix" : "ecs"
        }
      }
    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

# 4. ECS service
resource "aws_ecs_service" "pipelinecicd_service" {
  name            = "pipelinecicd-service-${var.run_id}"
  cluster         = aws_ecs_cluster.pipelinecicd_cluster.id
  task_definition = aws_ecs_task_definition.pipelinecicd_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.pipelinecicd_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pipelinecicd_tg.arn
    container_name   = "pipelinecicd-container"
    container_port   = 80
  }
}

# 5. Application Load Balancer (ALB)
resource "aws_lb" "pipelinecicd_alb" {
  name               = "pipelinecicd-service-${var.run_id}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.pipelinecicd_sg.id]
  subnets            = var.public_subnets 
}

# 6. Listener que apunta al Target Group
resource "aws_lb_listener" "pipelinecicd_listener" {
  load_balancer_arn = aws_lb.pipelinecicd_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.pipelinecicd_tg.arn
    type             = "forward"
  }
}

# 7. URL publica generada
output "pipelinecicd_environment_url" {
  description = "URL publica del ambiente CI/CD"
  value       = aws_lb.pipelinecicd_alb.dns_name
}