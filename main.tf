resource "aws_vpc" "my_vpc_test_task" {
    cidr_block = var.cidr_block


}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.my_vpc_test_task.id
    cidr_block = var.cidr_sub1
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}
resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.my_vpc_test_task.id
    cidr_block = var.cidr_sub2
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}
resource "aws_subnet" "private_sub1" {
    vpc_id = aws_vpc.my_vpc_test_task.id
    cidr_block = var.cidr_private1
    availability_zone = "us-east-1a"

}
resource "aws_subnet" "private_sub2" {
    vpc_id = aws_vpc.my_vpc_test_task.id
    cidr_block = var.cidr_private2
    availability_zone = "us-east-1b"

}

resource "aws_internet_gateway" "my_task_IG" {
    vpc_id = aws_vpc.my_vpc_test_task.id

}

resource "aws_route_table" "my_task_RT" {
    vpc_id = aws_vpc.my_vpc_test_task.id
    route {

        cidr_block = "0.0.0.0/0"
         gateway_id = aws_internet_gateway.my_task_IG.id
    }

}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
   route_table_id = aws_route_table.my_task_RT.id

}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
   route_table_id = aws_route_table.my_task_RT.id

}


resource "aws_security_group" "my_task_SG" {
  name        = "my_task_SG"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.my_vpc_test_task.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Egress rule allowing all traffic to leave the security group
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web-server1" {
ami = "ami-04b70fa74e45c3917"
instance_type = "t2.micro"
vpc_security_group_ids = [aws_security_group.my_task_SG.id]
subnet_id = aws_subnet.sub1.id
user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "web-server2" {
ami = "ami-04b70fa74e45c3917"
instance_type = "t2.micro"
vpc_security_group_ids = [aws_security_group.my_task_SG.id]
subnet_id = aws_subnet.sub2.id
user_data = base64encode(file("userdata1.sh"))
}


resource "aws_security_group" "myALB_SG" {
  name        = "myALB_SG"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.my_vpc_test_task.id

 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "my_task_ALB" {
    name = "myALB"
    internal = "false"
    load_balancer_type = "application"
    security_groups = [aws_security_group.myALB_SG.id]
    subnets = [aws_subnet.sub1.id ,aws_subnet.sub2.id]

    tags = {
        Name= "web-alb"
    }


}


resource "aws_lb_target_group" "myALB_TG" {
     name = "my-TG"
     port = 80
     protocol = "HTTP"
     vpc_id = aws_vpc.my_vpc_test_task.id

     health_check {
       path = "/"
       port = "traffic-port"

     }
}

resource "aws_lb_target_group_attachment" "my_lb_attachment" {
    target_group_arn = aws_lb_target_group.myALB_TG.arn
    target_id = aws_instance.web-server1.id
    port = 80

}

resource "aws_lb_target_group_attachment" "my_lb_attachment1" {
    target_group_arn = aws_lb_target_group.myALB_TG.arn
    target_id = aws_instance.web-server2.id
    port = 80

}


resource "aws_lb_listener" "lister" {
    load_balancer_arn = aws_alb.my_task_ALB.id
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.myALB_TG.arn
    }

}


resource "aws_db_subnet_group" "db_sub" {
    name= "db-subnet"

    subnet_ids = [ aws_subnet.private_sub1.id, aws_subnet.private_sub2.id ]


}

resource "aws_db_instance" "example" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7.34"
  instance_class       = "db.t2.micro"

  username             = "admin"
  password             = "7layer@#$%"
  db_subnet_group_name = aws_db_subnet_group.db_sub.name
  multi_az             = true
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.my_vpc_test_task.id


  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.my_task_SG.id}"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}




resource "aws_launch_configuration" "autoScale" {
  name          = "autoScale-launch-configuration"
  image_id      = "ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "autoScale_gp" {
  name                 = "autoScale_gp-autoscaling-group"
  launch_configuration = aws_launch_configuration.autoScale.name
  min_size             = 2
  max_size             = 5
  desired_capacity     = 2
  vpc_zone_identifier = [ aws_subnet.sub1.id, aws_subnet.sub2.id ]
}

resource "aws_autoscaling_policy" "autoScale_gp" {
  name                   = "example-scaling-policy"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoScale_gp.name
}

resource "aws_acm_certificate" "example" {
  domain_name       = "ewayexpress.com"
  validation_method = "DNS"
}


output "acm_certificate_validation_records" {
  value = aws_acm_certificate.example.domain_validation_options
}


resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_alb.my_task_ALB.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Default response"
      status_code  = "200"
    }
  }
  certificate_arn = aws_acm_certificate.example.arn
}




# Create a Route 53 hosted zone for your domain
resource "aws_route53_zone" "example" {
  name = "ewayexpress.com"
}

resource "aws_route53_record" "example" {
  zone_id = aws_route53_zone.example.zone_id
  name    = "www.ewayexpress.com"
  type    = "A"
  ttl     = "300"

  records = [aws_alb.my_task_ALB.dns_name] 
}
