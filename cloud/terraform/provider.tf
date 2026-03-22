terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 1.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.5.0"
}

# Provider OVH — credentials via variables d'environnement :
#   OVH_ENDPOINT (= ovh-eu)
#   OVH_APPLICATION_KEY
#   OVH_APPLICATION_SECRET
#   OVH_CONSUMER_KEY
provider "ovh" {
  endpoint = "ovh-eu"
}

# Provider OpenStack — credentials via variables d'environnement :
#   OS_AUTH_URL   = https://auth.cloud.ovh.net/v3
#   OS_TENANT_ID  = var.os_tenant_id
#   OS_PASSWORD
#   OS_USERNAME   = utilisateur OpenStack OVH
provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3"
  region      = var.ovh_region
  tenant_id   = var.os_tenant_id
}
