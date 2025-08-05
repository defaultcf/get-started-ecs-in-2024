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


# public

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

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_gw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# private

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

resource "aws_eip" "nat_gw" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  subnet_id     = aws_subnet.public[data.aws_availability_zones.ap_northeast_1.names[0]].id
  allocation_id = aws_eip.nat_gw.id

  tags = {
    Name = "main_nat_gw"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_egress_only_gw"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.main.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
