# Security group regulating database access
resource "aws_security_group" "rds" {
  name        = "free-tier-rds-sg"
  description = "Allow inbound DB access from application instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432 # Standard PostgreSQL port
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Restricts incoming access exclusively to internal VPC traffic
  }
}

# Free-Tier Eligible PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20                      # 20 GB storage limit (Free tier allows up to 20 GB)
  max_allocated_storage  = 20                      # Disables auto-scaling storage to prevent unexpected billing
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"          # FREE-TIER ELIGIBLE instance type
  db_name                = "appdb"
  username               = "dbadmin"
  password               = var.db_password         # Reads from variables.tf
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false                   # Keeps database hidden from the public internet
  skip_final_snapshot    = true                    # Allows fast tear-down during development
}