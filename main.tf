provider "aws" {
    region = var.region
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable region {}
variable az {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable env_prefix {}
variable ssh_private_key {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id     = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone = var.az
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

# using default route table (main), so that we don't need to make subnet association

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name = "${var.env_prefix}-main-rtb"
  }
}

resource "aws_default_security_group" "default-sg" {
  vpc_id      = aws_vpc.myapp-vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_ip]
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_prefix}-default-sg"
  }
}


data "aws_ami" "Latest-amazon-linux-image" {
    most_recent = true
    owners = ["137112412989"]
    
    filter {
        name   = "name"
        values = ["amzn2-ami-kernel-*-x86_64-gp2"] 
  }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }   
}

output "aws_ami_id" {
  value       = data.aws_ami.Latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value       = aws_instance.myapp-server.public_ip
}

resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.Latest-amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.az
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    Name = "${var.env_prefix}-server"
  }

  # provisioner "local-exec" {
  #   working_dir= "/home/ahmed/ansible-docker" # if the path of playbook wasn't the same.
  #   command= "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.ssh_private_key} --user ec2-user deploy-docker.yml" 
  #   # the path of the playbook in the same terraform project path, if not, we have to specify the full path of the playbook.
  # }
  # # inventroy will replace the hosts file
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "server-key"
  public_key = file(var.public_key_location)
}

# The "null_resource" resource implements the standard resource lifecycle but takes no further action.
# The triggers argument allows specifying an arbitrary set of values that, when changed, will cause the resource to be replaced.
# we can use it to separate the provisioner from the instance above

resource "null_resource" "configure_server" {
  triggers= {   # optional 
    trigger = aws_instance.myapp-server.public_ip  # this means every time the IP changes, the ansible-playbook will be executed.
  }
  provisioner "local-exec" {
  working_dir= "/home/ahmed/ansible-docker" # if the path of playbook wasn't the same.
  command= "ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.ssh_private_key} --user ec2-user deploy-docker.yml" 
  # the path of the playbook in the same terraform project path, if not, we have to specify the full path of the playbook. # inventroy will replace the hosts file
  }
}