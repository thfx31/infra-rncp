terraform {
  backend "s3" {
    bucket = "terraform-state-rncp"
    key    = "cloud/terraform.tfstate"
    region = "gra"

    # Endpoint OVH Object Storage compatible S3
    endpoints = {
      s3 = "https://s3.gra.cloud.ovh.net"
    }

    # Désactiver les vérifications AWS non supportées par OVH
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true

    # Credentials via variables d'environnement :
    #   TF_BACKEND_ACCESS_KEY (= AWS_ACCESS_KEY_ID)
    #   TF_BACKEND_SECRET_KEY (= AWS_SECRET_ACCESS_KEY)
  }
}
