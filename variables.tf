variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "selenium_version" {
  type        = string
  default     = "4.51.0-20261010"
  description = "Tag shared by the docker.io/selenium/hub and node images, such as \"4.51.0-20261010\". Change the image digests with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]{8}$", var.selenium_version))
    error_message = "selenium_version must be a full tag with its build date, such as \"4.51.0-20261010\"."
  }
}

variable "hub_image_digest" {
  type        = string
  default     = "sha256:4f94ce0ca99cb98234cd86829a9659eccf1b641277eb212f7101b0d96b3fe998"
  description = "Digest of docker.io/selenium/hub for selenium_version. Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.hub_image_digest))
    error_message = "hub_image_digest must be \"sha256:\" followed by 64 hex digits."
  }
}

variable "chromium_image_digest" {
  type        = string
  default     = "sha256:1aa008be6564d821ad6e3f916fb1a778ed144231ca8a52011ead7af63be8f24e"
  description = "Digest of docker.io/selenium/node-chromium for selenium_version."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.chromium_image_digest))
    error_message = "chromium_image_digest must be \"sha256:\" followed by 64 hex digits."
  }
}

variable "firefox_image_digest" {
  type        = string
  default     = "sha256:e6a109a147cddeb2d5e17cb639760e43e18ce9d6f0611947412917351b8e3bdd"
  description = "Digest of docker.io/selenium/node-firefox for selenium_version."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.firefox_image_digest))
    error_message = "firefox_image_digest must be \"sha256:\" followed by 64 hex digits."
  }
}

variable "browsers" {
  type        = list(string)
  default     = ["chromium"]
  description = "Browsers to run, each in a node of its own: \"chromium\", \"firefox\" or both."

  validation {
    condition     = length(var.browsers) > 0 && length(distinct(var.browsers)) == length(var.browsers) && alltrue([for b in var.browsers : contains(["chromium", "firefox"], b)])
    error_message = "browsers is a list of one or both of \"chromium\" and \"firefox\", without repeats."
  }
}

variable "node_max_sessions" {
  type        = number
  default     = 1
  description = "Browser sessions each node runs at once. Allow about 1 GB of memory for each."

  validation {
    condition     = var.node_max_sessions >= 1 && floor(var.node_max_sessions) == var.node_max_sessions
    error_message = "node_max_sessions must be a whole number, 1 or more."
  }
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "IPv4 address the Grid listens on. The Grid has no authentication, so anyone who can reach this address can drive its browsers. Read the README before changing it."

  validation {
    condition     = can(cidrhost("${var.listen_address}/32", 0)) && !strcontains(var.listen_address, ":")
    error_message = "listen_address must be an IPv4 address, such as \"127.0.0.1\"."
  }
}

variable "port" {
  type        = number
  default     = 4444
  description = "Port the Grid listens on."

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number from 1 to 65535."
  }
}
