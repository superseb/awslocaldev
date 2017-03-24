resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "vpc" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.id}"
}

resource "aws_eip" "nat" {
  vpc   = true
}

resource "aws_security_group" "steppingstone" {
  name        = "steppingstone"
  description = "steppingstone"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OpenVPN access
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "steppingstone" {
  ami                         = "${var.aws_ami_coreos}"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = ["${aws_security_group.steppingstone.id}"]
  subnet_id                   = "${aws_subnet.public.id}"
  associate_public_ip_address = true
  key_name                    = "${var.aws_keypair}"
  depends_on                  = ["aws_route_table_association.private"]
}

resource "aws_instance" "rancher" {
  ami                    = "${var.aws_ami_coreos}"
  instance_type          = "t2.medium"
  vpc_security_group_ids = ["${aws_security_group.sgpriv.id}"]
  subnet_id              = "${aws_subnet.private.id}"
  key_name               = "${var.aws_keypair}"
  depends_on             = ["aws_route_table_association.private"]
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = "eu-central-1a"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

# Route table private
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }
}

# Connect route to subnet
resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.vpc.id}"
}

resource "aws_security_group" "sgpriv" {
  name        = "sgpriv"
  description = "sgpriv"
  vpc_id      = "${aws_vpc.vpc.id}"

  # All ports open for vpc
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
