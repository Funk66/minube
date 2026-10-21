terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.11.0, < 3.0.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

locals {
  # Outer workspace image: Docker-in-Docker and Node.js for the Dev Containers CLI.
  # For reproducible deployments, replace this tag with a tested image digest.
  workspace_image = "codercom/enterprise-node:ubuntu"

  git_author_name = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)

  common_labels = {
    "coder.owner"        = data.coder_workspace_owner.me.name
    "coder.owner_id"     = data.coder_workspace_owner.me.id
    "coder.workspace_id" = data.coder_workspace.me.id
  }
  volume_labels = merge(local.common_labels, {
    "coder.workspace_name_at_creation" = data.coder_workspace.me.name
  })
  container_labels = merge(local.common_labels, {
    "coder.workspace_name" = data.coder_workspace.me.name
  })
}

variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI"
  type        = string
}

data "coder_parameter" "repo_name" {
  type         = "string"
  name         = "repo_name"
  display_name = "Repository name"
  description  = "Public repository under github.com/Funk66 containing a DevContainer configuration. Enter just the name, for example vim."
  default      = "vim"
  mutable      = false

  validation {
    regex = "^[A-Za-z0-9][A-Za-z0-9._-]*$"
    error = "Enter a repository name, such as vim, rather than a URL or owner/repo."
  }
}

provider "docker" {
  # An empty value uses the Docker provider's default connection settings.
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch            = data.coder_provisioner.me.arch
  os              = "linux"
  startup_script  = <<-EOT
    set -e

    # Initialize the persistent home once, preserving existing user files.
    if [ ! -f "$HOME/.init_done" ]; then
      cp -rn /etc/skel/. "$HOME/"
      touch "$HOME/.init_done"
    fi
  EOT
  shutdown_script = <<-EOT
    set -e

    # Stop Docker cleanly. Its images and cache live on the persistent volume.
    sudo service docker stop
  EOT

  # Git identity for terminals and scripts running on the outer workspace agent.
  # These values take precedence over Git configuration files.
  env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # Normalize host load by all installed CPUs, rather than the container's limit.
    script   = <<-EOT
      awk -v cpus="$(nproc --all)" '{ printf "%0.2f", $1 / cpus }' /proc/loadavg
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

resource "coder_script" "init_docker_in_docker" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.main.id
  display_name       = "Initialize Docker-in-Docker"
  run_on_start       = true
  start_blocks_login = true
  timeout            = 120
  icon               = "/icon/docker.svg"

  # This deployment uses coder.guirao.net; no localhost DNS/NAT workaround is needed.
  script = <<-EOT
    #!/bin/sh
    set -eu

    echo "Preserving process limits inherited from the Podman host..."
    sudo sed -i \
      -e 's/^[[:space:]]*ulimit -u unlimited[[:space:]]*$/: # Keep inherited process limit/' \
      -e 's/^[[:space:]]*ulimit -p unlimited[[:space:]]*$/: # Keep inherited process limit/' \
      /etc/init.d/docker
    sudo sh -n /etc/init.d/docker

    echo "Starting Docker..."
    if ! sudo service docker status >/dev/null 2>&1; then
      sudo service docker start
    fi

    # The init script starts dockerd in the background; wait for the API.
    attempt=0
    until docker info >/dev/null 2>&1; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge 60 ]; then
        echo "Docker did not become ready within the startup polling limit." >&2
        sudo tail -n 80 /var/log/docker.log >&2 || true
        exit 1
      fi
      sleep 1
    done
    echo "Docker is ready."
  EOT
}

# See https://registry.coder.com/modules/coder/devcontainers-cli
module "devcontainers-cli" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/devcontainers-cli/coder"
  agent_id = coder_agent.main.id

  # Allow updates within the current major version; pin a tested version for releases.
  version = "~> 1.0"
}

# Require GitHub authentication for authenticated Git operations.
data "coder_external_auth" "github" {
  id = "primary-github"
}

# See https://registry.coder.com/modules/coder/git-clone
module "git-clone" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-clone/coder"
  agent_id = coder_agent.main.id
  url      = "https://github.com/Funk66/${data.coder_parameter.repo_name.value}.git"
  base_dir = "~"
  # Allow updates within the current major version; pin a tested version for releases.
  version = "~> 2.0"
}

# Automatically start the devcontainer for the workspace.
resource "coder_devcontainer" "repo" {
  count            = data.coder_workspace.me.start_count
  agent_id         = coder_agent.main.id
  workspace_folder = "~/${module.git-clone[0].folder_name}"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Ignore attribute updates that could replace this persistent volume.
  # Workspace deletion still destroys the volume.
  lifecycle {
    ignore_changes = all
  }
  dynamic "labels" {
    for_each = local.volume_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_volume" "docker_volume" {
  name = "coder-${data.coder_workspace.me.id}-docker"
  # Ignore attribute updates that could replace this persistent volume.
  # Workspace deletion still destroys the volume.
  lifecycle {
    ignore_changes = all
  }
  dynamic "labels" {
    for_each = local.volume_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = local.workspace_image

  # Required by the Docker-in-Docker setup inside this workspace.
  privileged = true

  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  command  = ["sh", "-c", coder_agent.main.init_script]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}"
  ]
  # Reach this deployment's Coder server through the outer container gateway.
  host {
    host = "coder.guirao.net"
    ip   = "host-gateway"
  }

  # Workspace home volume persists user data across workspace restarts.
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  # Workspace docker volume persists Docker data across workspace
  # restarts, allowing the devcontainer cache to be reused.
  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.docker_volume.name
    read_only      = false
  }

  dynamic "labels" {
    for_each = local.container_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
