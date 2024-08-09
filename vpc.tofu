resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"

  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "main"
  }
}

data "aws_availability_zones" "ap_northeast_1" {
  state = "available"

  filter {
    name   = "region-name"
    values = ["ap-northeast-1"]
  }
}

resource "aws_subnet" "public" {
  for_each = toset(data.aws_availability_zones.ap_northeast_1.names)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, index(data.aws_availability_zones.ap_northeast_1.names, each.key))
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, index(data.aws_availability_zones.ap_northeast_1.names, each.key))
  availability_zone = each.key

  map_public_ip_on_launch = true
  enable_dns64            = true

  tags = {
    Name = "${each.key}-public"
  }
}

resource "aws_subnet" "private" {
  for_each = toset(data.aws_availability_zones.ap_northeast_1.names)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, index(data.aws_availability_zones.ap_northeast_1.names, each.key) + length(aws_subnet.public))
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, index(data.aws_availability_zones.ap_northeast_1.names, each.key) + length(aws_subnet.public))
  availability_zone = each.key

  map_public_ip_on_launch = true
  enable_dns64            = true

  tags = {
    Name = "${each.key}-private"
  }
}
