locals {
  hub_image = "docker.io/selenium/hub:${var.selenium_version}@${var.hub_image_digest}"
  node_images = {
    chromium = "docker.io/selenium/node-chromium:${var.selenium_version}@${var.chromium_image_digest}"
    firefox  = "docker.io/selenium/node-firefox:${var.selenium_version}@${var.firefox_image_digest}"
  }

  # VNC is off because nothing publishes it and it would be one more server
  # beside a browser that loads whatever it's told to. Only 4444 leaves the
  # network: the event bus on 4442 and 4443 takes registrations from anyone
  # who can reach it, so it stays between these containers.
  nodes = {
    for b in var.browsers : "selenium-node-${b}" => {
      image = local.node_images[b]
      environment = {
        SE_EVENT_BUS_HOST             = "selenium-hub"
        SE_EVENT_BUS_PUBLISH_PORT     = "4442"
        SE_EVENT_BUS_SUBSCRIBE_PORT   = "4443"
        SE_NODE_MAX_SESSIONS          = tostring(var.node_max_sessions)
        SE_NODE_OVERRIDE_MAX_SESSIONS = tostring(var.node_max_sessions > 1)
        SE_START_VNC                  = "false"
        SE_START_NO_VNC               = "false"
      }
      extra = [
        "Network=selenium.network",
        # Browsers crash on the 64 MB /dev/shm a container gets by default.
        "PodmanArgs=--shm-size=2g",
      ]
    }
  }
}

circuit "network" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # A network of its own gives the nodes the hub's name through Podman's DNS,
  # and lets the hub's ports stay off the host. The host's network would put
  # the event bus on every address.
  step "network" {
    file {
      path    = "/etc/containers/systemd/selenium.network"
      content = "# Managed by Conn3x.\n[Network]\nNetworkName=selenium\n"
    }
  }
}

module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_file.network__network]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = merge({
    selenium-hub = {
      image = local.hub_image
      ports = ["${var.listen_address}:${var.port}:4444"]
      extra = ["Network=selenium.network"]
    }
  }, local.nodes)
}

circuit "selenium" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # The Grid says it's ready once a node has registered. wait_for can't see
  # this: a published port is a firewall rule, with no listener on the host.
  step "ready" {
    depends_on = [module.podman]
    command {
      command = <<-EOT
        for _ in $(seq 150); do
          podman exec selenium-hub curl -sf http://127.0.0.1:4444/status | grep -q '"ready": *true' && exit 0
          sleep 2
        done
        echo "The Grid didn't report ready within 5 minutes." >&2
        exit 1
      EOT
      unless  = "podman exec selenium-hub curl -sf http://127.0.0.1:4444/status | grep -q '\"ready\": *true'"
    }
  }
}
