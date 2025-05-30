terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
  }
}
provider "aws" {
  region = "us-east-2"
  profile = "default"  # or name of your configured profile
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "nginx" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public[count.index].id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              echo "<html>
              <head>
                <title>Welcome to Srinidhi's website of nginx and load balancer project</title>
              </head>
              <body style='font-family:Arial; text-align:center; margin-top:100px; background-color:#f0f8ff;'>
                <h1 style='color:#2e8b57;'>Welcome to Srinidhi's website of nginx and load balancer project</h1>
                <h2>Running on Instance: <span style='color:#ff4500;'>$INSTANCE_ID</span></h2>
              </body>
              </html>" > /usr/share/nginx/html/index.html
            EOF


  tags = {
    Name = "nginx-${count.index}"
  }
}



resource "aws_lb" "app_lb" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.nginx[count.index].id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}