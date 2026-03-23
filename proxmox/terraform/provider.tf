terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93"
    }
  }
}

provider "proxmox" {
  # Configuré via variables d'environnement :
  #   PROXMOX_VE_ENDPOINT  = "https://192.168.x.x:8006/"
  #   PROXMOX_VE_API_TOKEN = "terraform@pam!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #
  # Format du token bpg : "user@realm!tokenname=secret" (tout en une seule variable)

  insecure = true # Certificat auto-signé Proxmox
}
