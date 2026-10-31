variable "port" {
  type    = number
  default = 2222
}

variable "browsers" {
  type    = list(string)
  default = ["chromium"]
}

module "selenium" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  browsers = var.browsers
}

output "grid_url" {
  value = module.selenium.grid_url
}
