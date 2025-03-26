terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Define variables
variable "do_token" {
  description = "DigitalOcean API token"
}

variable "ssh_key_name" {
  description = "Name of the SSH key in DigitalOcean"
}

# Configure the DigitalOcean provider
provider "digitalocean" {
  token = var.do_token
}

# Fetch the SSH key from DigitalOcean using the variable
data "digitalocean_ssh_key" "terraform" {
  name = var.ssh_key_name   
}
