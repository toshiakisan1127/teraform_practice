resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "example"
  }
}


resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}


resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  value = aws_vpc.example.id
}

output "public_subnet_route_table_id" {
  value = aws_route_table.public.id
}

resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_eip" "nat_gateway_0" {
  vpc = true
  depends_on = [
    aws_internet_gateway.example
  ]
}

resource "aws_eip" "nat_gateway_1" {
  vpc = true
  depends_on = [
    aws_internet_gateway.example
  ]
}
resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on = [
    aws_internet_gateway.example
  ]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on = [
    aws_internet_gateway.example
  ]
}
resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}


module "example_sg" {
  source      = "./security_group"
  name        = "module-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"] # ?????????IP?????????????????????????????????????????????????????????
}

resource "aws_lb" "example" {
  name                       = "example"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id
  ]
}

module "http_sg" {
  source      = "./security_group"
  name        = "http_sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.example.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "http-redirect-sg"
  vpc_id      = aws_vpc.example.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "????????????HTTP?????????"
      status_code  = "200"
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}

data "aws_route53_zone" "example" {
  name = "toshiakisan1127.com"
}

resource "aws_route53_record" "test_example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = data.aws_route53_zone.example.name
  type    = "A"

  alias {
    name                   = aws_lb.example.dns_name
    zone_id                = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.test_example.name
}

resource "aws_acm_certificate" "example" {
  domain_name               = aws_route53_record.test_example.name
  subject_alternative_names = []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "example_certificate" {

  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  type    = each.value.type
  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
  # for_each = {
  #   for cert in aws_route53_record.example_certificate : cert.fqdn => {
  #     fqdn = cert.fqnd
  #   }
  # }
  # validation_record_fqdns = [each.value]

  validation_record_fqdns = [aws_route53_record.example_certificate[data.aws_route53_zone.example.name].fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "????????????HTTPS?????????"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "example" {
  name                 = "example"
  target_type          = "ip"
  vpc_id               = aws_vpc.example.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  depends_on = [
    aws_lb.example
  ]
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
