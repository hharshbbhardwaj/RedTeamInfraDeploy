# Droplet 1: Evilginx Server
resource "digitalocean_droplet" "evilginx_server" {
  name   = "evilginx-server"
  region = "blr1"               # Bangalore region 
  size   = "s-1vcpu-1gb"        # Size: 1 GB RAM / 1 AMD CPU / 25 GB SSD / 1000 GB transfer
  image  = "ubuntu-22-04-x64"   # Ubuntu 22.04 LTS image
  
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
}

# Droplet 2: Gophish Server
resource "digitalocean_droplet" "gophish_server" {
  name   = "gophish-server"
  region = "blr1"
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
}

# Droplet 3: C2 Havoc Server
resource "digitalocean_droplet" "c2_havoc" {
  name   = "c2-havoc"
  region = "blr1"
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
}

# Droplet 4: C2 Redirector
resource "digitalocean_droplet" "c2_redirector" {
  name   = "c2-redirector"
  region = "blr1"
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
}

# Outputs: Public IPs for each droplet
output "evilginx_server_ip" {
  value = digitalocean_droplet.evilginx_server.ipv4_address
}

output "gophish_server_ip" {
  value = digitalocean_droplet.gophish_server.ipv4_address
}

output "c2_havoc_ip" {
  value = digitalocean_droplet.c2_havoc.ipv4_address
}

output "c2_redirector_ip" {
  value = digitalocean_droplet.c2_redirector.ipv4_address
}

