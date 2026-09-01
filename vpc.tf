# vpc.tf

# --- The VPC itself ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# --- Internet Gateway ---
# This is what allows anything in a PUBLIC subnet to reach (and be reached
# from) the internet. A VPC has exactly one IGW attached to it.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# --- Public subnets (one per AZ) ---
# `cidrsubnet()` is a Terraform function that carves smaller ranges out of
# our /16. count.index (0, 1, ...) picks a different slice for each subnet
# so they don't overlap. Public subnets get index 0 and 1.
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # instances here auto-get a public IP

  tags = {
    Name = "${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# --- Private subnets (one per AZ) ---
# Index offset by 10 (10, 11, ...) purely so the CIDR ranges are visually
# distinct from the public ones when you look at them — not a technical
# requirement, just a readability habit.
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

# --- Elastic IP for the NAT Gateway ---
# NAT Gateways need a static public IP to present to the internet.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

# --- NAT Gateway ---
# Lives in a PUBLIC subnet, and lets resources in PRIVATE subnets make
# outbound internet requests (e.g. Lambda downloading a dependency, or an
# instance fetching OS updates) without being directly reachable from the
# internet themselves.
#
# COST NOTE (good interview talking point): a NAT Gateway costs ~$0.045/hr
# plus per-GB data processing charges — it's the single most expensive thing
# in this whole project (~$32/month just sitting idle). A real production
# setup often runs ONE NAT Gateway PER AZ for high availability (if one AZ's
# NAT fails, the other AZ's private subnet is unaffected). We're using just
# ONE NAT Gateway total here to keep this project cheap to run — that's a
# deliberate cost-vs-availability trade-off you should be ready to explain:
# "I used a single NAT Gateway to minimize cost for a portfolio project, but
# in production I'd run one per AZ to avoid a single point of failure."
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# --- Route table for public subnets ---
# A route table is a set of rules: "traffic headed to X, send it via Y."
# Here: traffic to anywhere (0.0.0.0/0) goes out via the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route table for private subnets ---
# Same idea, but outbound traffic goes via the NAT Gateway instead of
# directly via the IGW — so these subnets stay unreachable from the internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
