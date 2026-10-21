resource "aws_vpc" "vpc_6776A399" {
  cidr_block                       = "10.0.0.0/24"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  tags = {
    Name = "minube"
  }
}

resource "aws_internet_gateway" "vpc_igw_E5E304CC" {
  vpc_id = aws_vpc.vpc_6776A399.id
  tags = {
    Name = "minube"
  }
}

resource "aws_route_table" "vpc_routeTable_FC8D1E91" {
  vpc_id = aws_vpc.vpc_6776A399.id
  tags = {
    Name = "minube"
  }
}

resource "aws_route" "vpc_route4_93D95A3C" {
  route_table_id         = aws_route_table.vpc_routeTable_FC8D1E91.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc_igw_E5E304CC.id
}

resource "aws_route" "vpc_route6_BC6C2BF8" {
  route_table_id              = aws_route_table.vpc_routeTable_FC8D1E91.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.vpc_igw_E5E304CC.id
}

resource "aws_subnet" "vpc_subnet_376FC355" {
  vpc_id                          = aws_vpc.vpc_6776A399.id
  cidr_block                      = cidrsubnet(aws_vpc.vpc_6776A399.cidr_block, 2, 0)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc_6776A399.ipv6_cidr_block, 8, 0)
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "minube"
  }
}

resource "aws_route_table_association" "vpc_routeTableAssociation_B59F732F" {
  route_table_id = aws_route_table.vpc_routeTable_FC8D1E91.id
  subnet_id      = aws_subnet.vpc_subnet_376FC355.id
}

resource "aws_vpc_endpoint" "vpc_s3Endpoint_8F340651" {
  vpc_id          = aws_vpc.vpc_6776A399.id
  service_name    = "com.amazonaws.eu-central-1.s3"
  route_table_ids = [aws_route_table.vpc_routeTable_FC8D1E91.id]
  tags = {
    Name = "minube-s3-endpoint"
  }
}
