#!/usr/bin/env python3
"""
Inventaire Ansible dynamique — lit tf_outputs.json généré par terraform output -json
"""

import json
import os
import sys

TF_OUTPUTS_FILE = os.path.join(os.path.dirname(__file__), "tf_outputs.json")


def load_tf_outputs():
    if not os.path.exists(TF_OUTPUTS_FILE):
        print(
            f"[inventory.py] Fichier {TF_OUTPUTS_FILE} introuvable.\n"
            "Lancer d'abord : make inventory",
            file=sys.stderr,
        )
        sys.exit(1)
    with open(TF_OUTPUTS_FILE) as f:
        return json.load(f)


def build_inventory(outputs):
    cp_ip  = outputs["control_plane_ip_public"]["value"]
    w01_ip = outputs["worker01_ip_public"]["value"]
    w02_ip = outputs["worker02_ip_public"]["value"]

    return {
        "_meta": {
            "hostvars": {
                "scw-cp-01": {
                    "ansible_host": cp_ip,
                    "private_ip":   cp_ip,
                },
                "scw-worker-01": {
                    "ansible_host": w01_ip,
                },
                "scw-worker-02": {
                    "ansible_host": w02_ip,
                },
            }
        },
        "control_plane": {
            "hosts": ["scw-cp-01"],
        },
        "workers": {
            "hosts": ["scw-worker-01", "scw-worker-02"],
        },
        "k8s_cluster": {
            "children": ["control_plane", "workers"],
        },
        "all": {
            "vars": {
                "ansible_user":                "almalinux",
                "ansible_ssh_private_key_file": "~/.ssh/id_ed25519",
                "ansible_ssh_common_args":      "-o StrictHostKeyChecking=no",
            }
        },
    }


if __name__ == "__main__":
    outputs = load_tf_outputs()
    inventory = build_inventory(outputs)
    print(json.dumps(inventory, indent=2))
