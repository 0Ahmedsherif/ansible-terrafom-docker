terraform {
backend "s3" {
    bucket         = "ansible-docker-buc"
    key            = "ansible/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ansible-docker"
}
}