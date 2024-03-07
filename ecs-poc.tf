provider "aws" {
  region = "af-south-1"  # Specify your desired region
}

resource "aws_ecs_cluster" "poc_cluster" {
  name = "poc-cluster"
}

resource "aws_ecs_task_definition" "poc_task" {
  family                   = "poc-task-family"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions    = jsonencode([{
    name      = "poc-container"
    image     = "nginx:latest"  # Specify your container image
    portMappings {
      containerPort = 80
    }
  }])
}

resource "aws_iam_role" "task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })

    inline_policy {
    name = "task_execution_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = ["ecs:*"]
        Resource  = ["*"]
      }]
    })
  }
}


resource "aws_iam_role" "task_role" {
  name               = "ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })

   inline_policy {
    name = "task_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = ["ecs:RunTask", "ecs:StopTask", "ecs:DescribeTasks", "ecs:ListTasks", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource  = ["*"]
      }]
    })
  }
}


resource "aws_ecs_service" "poc_service" {
  name            = "poc-service"
  cluster         = aws_ecs_cluster.poc_cluster.id
  task_definition = aws_ecs_task_definition.poc_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"  # Or "EC2" if you're using EC2 launch type
  network_configuration {
    subnets         = ["......"]  # Specify your subnet ID
    security_groups = ["....."]     # Specify your security group ID
    assign_public_ip = true
  }
}


resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.poc_cluster.name}/${aws_ecs_service.poc_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_policy" "ecs_service_scaling_policy" {
  name               = "example-service-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown   = 300
    scale_out_cooldown  = 300
    target_value        = 50.0
  }
}

resource "aws_cloudwatch_event_rule" "poc_scheduled_task_rule" {
  name                = "poc-scheduled-task-rule"
  schedule_expression = "cron(0 5 25 * ? *)"
}

resource "aws_cloudwatch_event_target" "poc_scheduled_task_target" {
  rule      = aws_cloudwatch_event_rule.poc_scheduled_task_rule.name
  arn       = aws_ecs_service.poc_service.arn
  role_arn  = aws_iam_role.task_execution_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.poc_task.arn
  }




  
