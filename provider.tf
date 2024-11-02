provider "aws" {
    shared_config_files = [".aws/config", "~/.aws/config"]
    shared_credentials_files = [".aws/credentials", "~/.aws/credentials"]
    region  = "us-east-1"
    profile = "default"
}
