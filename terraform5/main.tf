provider "aws" {
 region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraformstateprotag"
    key    = "config2/terraform.tfstate"
    region = "us-east-1"
  }
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name             = "Prod"
  cidr             = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_dns_hostnames = true
  enable_dns_support = true
  enable_nat_gateway = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

data "aws_subnets" "default" {
  depends_on = [
    module.vpc
  ]
    filter {
      name="vpc-id"
      values = [module.vpc.vpc_id]
}
}

######################### ASG #############################

resource "aws_launch_configuration" "example" {
 image_id = "ami-007855ac798b5175e"
 instance_type = "t2.micro"
 security_groups = [aws_security_group.instance.id]
 user_data = <<-EOF
 #!/bin/bash
 echo "Hello, World" > index.xhtml
 nohup busybox httpd -f -p ${var.server_port} &
 EOF

# Required when using a launch configuration with an autoscaling group.
 lifecycle {
 create_before_destroy = true
 }
}

resource "aws_autoscaling_group" "example" {
 launch_configuration = aws_launch_configuration.example.name
 vpc_zone_identifier = module.vpc.public_subnets
 min_size = 2
 max_size = 3
 tag {
 key = "Name"
 value = "terraform-asg-example"
 propagate_at_launch = true
 }
}

resource "aws_security_group" "instance" {
  name        = "webapp-ASG-sg"
  description = "Allow tcp inbound traffic on port 5000"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port        = var.server_port
    to_port          = var.server_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

############################## LB ##############################

resource "aws_alb" "example" {
  name = "AWS-ALB"
  load_balancer_type = "application"
  subnets = module.vpc.public_subnets
  security_groups = [aws_security_group.ALB.id]
}

resource "aws_security_group" "ALB" {
  name        = "ALB-sg"
  description = "Allow TLS inbound traffic"
  vpc_id = module.vpc.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


resource "aws_alb_listener" "example" {
  load_balancer_arn = aws_alb.example.arn
  port = 80
  protocol = "HTTP"

  # By default, return a simple 404 page
 default_action {
 type = "fixed-response"
 fixed_response {
 content_type = "text/plain"
 message_body = "404: page not found"
 status_code = 404
 }
 }
}

resource "aws_lb_target_group" "lb-tg" {
  name     = "tf-lb-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_alb_listener.example.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

output "alb_dns_name" {
  value=aws_alb.example.dns_name
  description = "domain name of LB"
}