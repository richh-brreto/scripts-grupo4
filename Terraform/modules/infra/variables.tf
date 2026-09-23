variable "region" {
  description = "Região AWS onde a infraestrutura será provisionada"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (dev, homolog, prod)"
  type        = string
  default     = "dev"
}
variable "project_name" {
  description = "Prefixo usado no nome/tags de todos os recursos"
  type        = string
  default     = "Boost"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones utilizadas (posição 0 = AZ 'a', posição 1 = AZ 'b')"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_a_cidr" {
  description = "CIDR da subnet pública (bastion / ALB) na AZ a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR da subnet pública (ALB) na AZ b"
  type        = string
  default     = "10.0.5.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR da subnet privada de aplicação na AZ a"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR da subnet privada de aplicação na AZ b"
  type        = string
  default     = "10.0.3.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR da subnet privada de banco de dados"
  type        = string
  default     = "10.0.4.0/24"
}

variable "instance_type" {
  description = "Tipo de instância EC2 usado em todas as instâncias"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Nome do key pair já existente na AWS, usado para acesso SSH"
  type        = string
  default     = "key-server"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_session_token" {
  type      = string
  sensitive = true
  default   = ""
}
