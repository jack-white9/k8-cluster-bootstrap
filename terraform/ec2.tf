resource "aws_security_group" "k8s" {
  name        = "k8-cluster-sg"
  description = "Security group for bootstrapped Kubernetes cluster"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k8s.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "jumpbox" {
  ami                    = local.amis.debian_bookworm.ap_southeast_2.arm64
  instance_type          = "t4g.nano"
  key_name               = "k8-jumpbox-key-pair" # Created with CLI
  vpc_security_group_ids = [aws_security_group.k8s.id]
  subnet_id              = module.vpc.public_subnets[0]

  associate_public_ip_address = true

  tags = {
    Name = "k8-jumpbox"
  }
}

resource "aws_instance" "server" {
  ami                    = local.amis.debian_bookworm.ap_southeast_2.arm64
  instance_type          = "t4g.small"
  key_name               = "k8-server-key-pair" # Created with CLI
  vpc_security_group_ids = [aws_security_group.k8s.id]
  subnet_id              = module.vpc.public_subnets[0]

  associate_public_ip_address = true

  tags = {
    Name = "k8-server"
  }
}

resource "aws_instance" "node_0" {
  ami                    = local.amis.debian_bookworm.ap_southeast_2.arm64
  instance_type          = "t4g.small"
  key_name               = "k8-node-0-key-pair" # Created with CLI
  vpc_security_group_ids = [aws_security_group.k8s.id]
  subnet_id              = module.vpc.public_subnets[0]

  associate_public_ip_address = true

  tags = {
    Name = "k8-node-0"
  }
}

resource "aws_instance" "node_1" {
  ami                    = local.amis.debian_bookworm.ap_southeast_2.arm64
  instance_type          = "t4g.small"
  key_name               = "k8-node-1-key-pair" # Created with CLI
  vpc_security_group_ids = [aws_security_group.k8s.id]
  subnet_id              = module.vpc.public_subnets[0]

  associate_public_ip_address = true

  tags = {
    Name = "k8-node-1"
  }
}
