resource "aws_security_group" "public" {
  name        = "${var.name}-public-sg"
  description = "Public test tier"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-sg"
    }
  )
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Application tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from public tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-app-sg"
    }
  )
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from application tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-sg"
    }
  )
}

