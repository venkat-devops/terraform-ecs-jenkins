provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
  profile    = "${var.profile}"
}

data "terraform_remote_state" "tfstate" {
  backend = "s3"

  config {
    bucket  = "bg-tfstate-1675"
    key     = "jenkins/terraform.tfstate"
    region  = "eu-west-2"
    profile = "mytf"
  }
}

resource "aws_vpc" "jenkins" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    for  = "${var.ecs_cluster_name}"
    Name = "ecs-jenkins-vpc"
  }
}

resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.jenkins.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.jenkins.id}"
  }

  tags {
    for = "${var.ecs_cluster_name}"
  }
}

resource "aws_route_table_association" "external-jenkins1" {
  subnet_id      = "${aws_subnet.jenkins1.id}"
  route_table_id = "${aws_route_table.external.id}"
}

resource "aws_route_table_association" "external-jenkins2" {
  subnet_id      = "${aws_subnet.jenkins2.id}"
  route_table_id = "${aws_route_table.external.id}"
}

resource "aws_subnet" "jenkins1" {
  vpc_id            = "${aws_vpc.jenkins.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"            // need to gget from the list var.availability_zones

  tags {
    Name = "${var.ecs_cluster_name}-subnet1"
  }
}

resource "aws_subnet" "jenkins2" {
  vpc_id            = "${aws_vpc.jenkins.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"            // need to gget from the list var.availability_zones

  tags {
    for = "${var.ecs_cluster_name}-subnet2"
  }
}

resource "aws_internet_gateway" "jenkins" {
  vpc_id = "${aws_vpc.jenkins.id}"

  tags {
    for = "${var.ecs_cluster_name}"
  }
}

resource "aws_security_group" "sg_jenkins" {
  name        = "sg_${var.ecs_cluster_name}"
  description = "Allows all traffic"
  vpc_id      = "${aws_vpc.jenkins.id}"

  tags {
    Name = "ecs-jenkins-sg"
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 50000
    to_port   = 50000
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_ecs_cluster" "jenkins" {
  name = "${var.ecs_cluster_name}"
}

resource "aws_autoscaling_group" "asg_jenkins" {
  name                      = "asg_${var.ecs_cluster_name}"
  availability_zones        = ["${var.availability_zones}"]
  min_size                  = "${var.min_instance_size}"
  max_size                  = "${var.max_instance_size}"
  desired_capacity          = "${var.desired_instance_capacity}"
  health_check_type         = "EC2"
  health_check_grace_period = 300
  launch_configuration      = "${aws_launch_configuration.lc_jenkins.name}"
  vpc_zone_identifier       = ["${aws_subnet.jenkins1.id}", "${aws_subnet.jenkins2.id}"]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.ecs_cluster_name}_asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_jenkins" {
  autoscaling_group_name = "${aws_autoscaling_group.asg_jenkins.id}"
  alb_target_group_arn   = "${aws_alb_target_group.ecs-target-group.arn}"
}

data "template_file" "user_data" {
  template = "${file("templates/user_data.tpl")}"

  vars {
    access_key       = "${var.access_key}"
    secret_key       = "${var.secret_key}"
    s3_bucket        = "${var.s3_bucket}"
    ecs_cluster_name = "${var.ecs_cluster_name}"
    restore_backup   = "${var.restore_backup}"
  }
}

resource "aws_launch_configuration" "lc_jenkins" {
  name_prefix                 = "lc_${var.ecs_cluster_name}-"
  image_id                    = "${lookup(var.amis, var.region)}"
  instance_type               = "${var.instance_type}"
  security_groups             = ["${aws_security_group.sg_jenkins.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.iam_instance_profile.name}"
  key_name                    = "${var.key_name}"
  associate_public_ip_address = true
  user_data                   = "${data.template_file.user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "host_role_jenkins" {
  name               = "host_role_${var.ecs_cluster_name}"
  assume_role_policy = "${file("policies/ecs-role.json")}"
}

resource "aws_iam_role_policy" "instance_role_policy_jenkins" {
  name   = "instance_role_policy_${var.ecs_cluster_name}"
  policy = "${file("policies/ecs-instance-role-policy.json")}"
  role   = "${aws_iam_role.host_role_jenkins.id}"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam_instance_profile_${var.ecs_cluster_name}"
  path = "/"
  role = "${aws_iam_role.host_role_jenkins.name}"
}

resource "aws_alb" "alb_jenkins" {
  name            = "ecs-load-balancer"
  security_groups = ["${aws_security_group.sg_jenkins.id}"]
  subnets         = ["${aws_subnet.jenkins1.id}", "${aws_subnet.jenkins2.id}"]

  tags {
    Name = "ecs-load-balancer"
  }
}

resource "aws_alb_target_group" "ecs-target-group" {
  name     = "ecs-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.jenkins.id}"

  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
  }

  tags {
    Name = "ecs-target-group"
  }
}

resource "aws_alb_listener" "alb-listener" {
  load_balancer_arn = "${aws_alb.alb_jenkins.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs-target-group.arn}"
    type             = "forward"
  }
}

output "aws_alb_id" {
  value = "${aws_alb.alb_jenkins.id}"
}

resource "aws_route53_record" "r53_jenkins" {
  zone_id = "${var.dns_zone_id}"
  name    = "jenkins.${var.dns_root}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_alb.alb_jenkins.dns_name}"]
}
