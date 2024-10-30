provider "aws" {
    shared_config_files = ["/Users/peric/.aws/config"] # Path to your AWS config file
    shared_credentials_files = ["/Users/peric/.aws/credentials"] # Path to your AWS credentials file
    region  = "us-east-1"
    profile = "default"
}
