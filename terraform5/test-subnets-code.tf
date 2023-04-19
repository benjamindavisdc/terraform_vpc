#<<-EOF
#resource "aws_vpc" "example" {
#  cidr_block = "10.0.0.0/16"
#}

#resource "aws_subnet" "example" {
#  count             = 3
#  cidr_block        = "10.0.${count.index}.0/24"
#  vpc_id            = aws_vpc.example.id
#  availability_zone = "us-east-1a"
#}

#data "aws_subnet_ids" "example" {
#  vpc_id = aws_vpc.example.id
#}

#output "subnet_ids" {
#  value = data.aws_subnet_ids.example.ids
#}
#EOF