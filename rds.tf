# --------------------------------------------------------------------------------
# 1. IAM Role for RDS Enhanced Monitoring (CKV_AWS_118)
# --------------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.cluster_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --------------------------------------------------------------------------------
# 2. PostgreSQL DB Parameter Group for Query Logging (CKV2_AWS_30)
# --------------------------------------------------------------------------------
resource "aws_db_parameter_group" "postgres" {
  name        = "${var.cluster_name}-pg16-params"
  family      = "postgres16"
  description = "Custom PostgreSQL 16 parameter group enabling query logging and security parameters"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "250"
  }
}

# --------------------------------------------------------------------------------
# 3. Security Group Regulating Database Access (CKV_AWS_23 & CKV_AWS_382)
# --------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "microservices-rds-sg"
  description = "Security group regulating PostgreSQL database access for internal VPC and EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow PostgreSQL traffic from internal VPC CIDR"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    description     = "Allow PostgreSQL traffic from EKS worker node security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow outbound traffic restricted to internal VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = {
    Name = "microservices-rds-sg"
  }
}

# --------------------------------------------------------------------------------
# 4. Production-Ready PostgreSQL Database Instance
# --------------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  allocated_storage     = 20
  max_allocated_storage = 100
  engine                = "postgres"
  engine_version        = "16"
  instance_class        = "db.t4g.micro"
  db_name               = "appdb"
  username              = "dbadmin"
  password              = var.db_password
  db_subnet_group_name  = module.vpc.database_subnet_group_name
  parameter_group_name  = aws_db_parameter_group.postgres.name

  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # CKV_AWS_16: Encryption at Rest
  storage_encrypted = true

  # CKV_AWS_226: Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # CKV_AWS_161: IAM Database Authentication
  iam_database_authentication_enabled = true

  # CKV_AWS_129: CloudWatch Log Exports
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # CKV_AWS_353: Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # CKV_AWS_118: Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # CKV_AWS_157: Multi-AZ High Availability
  multi_az = true

  # CKV_AWS_293: Deletion Protection
  deletion_protection       = var.enable_deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.cluster_name}-postgres-final-snapshot"

  # CKV2_AWS_60: Copy Tags to Snapshot
  copy_tags_to_snapshot = true
}