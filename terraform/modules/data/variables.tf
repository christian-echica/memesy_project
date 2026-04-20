variable "project"            { type = string }
variable "env"                { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "sg_rds_id"          { type = string }
variable "sg_redis_id"        { type = string }

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "db_name" {
  type    = string
  default = "memesy"
}

variable "db_username" {
  type    = string
  default = "memesy_admin"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.small"
}

variable "tags" {
  type    = map(string)
  default = {}
}
