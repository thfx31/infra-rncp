variable "ovh_region" {
  description = "Région OVH Public Cloud (ex: GRA11, SBG5, DE1)"
  type        = string
  default     = "SBG5"
}

variable "cluster_name" {
  description = "Préfixe des noms de ressources"
  type        = string
  default     = "rncp-ovh"
}

variable "flavor_cp" {
  description = "Flavor OVH pour le control plane (quota POC : b2-7 = 2 vCPUs / 7 Go)"
  type        = string
  default     = "b2-7"
}

variable "flavor_worker" {
  description = "Flavor OVH pour les workers (quota POC : b2-7 = 2 vCPUs / 7 Go)"
  type        = string
  default     = "b2-7"
}

variable "image_name" {
  description = "Image OS pour les instances (AlmaLinux 9)"
  type        = string
  default     = "AlmaLinux 9"
}

variable "ssh_key_name" {
  description = "Nom de la clé SSH enregistrée dans OVH Public Cloud"
  type        = string
}

variable "vrack_subnet" {
  description = "CIDR du subnet privé vRack"
  type        = string
  default     = "10.0.0.0/24"
}

variable "domain" {
  description = "Domaine principal des services exposés"
  type        = string
  default     = "k8s.yplank.fr"
}

variable "os_tenant_id" {
  description = "ID du projet OpenStack (OVH_TENANT_ID)"
  type        = string
  sensitive   = true
}
