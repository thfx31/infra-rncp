# ──────────────────────────────────────────────────────────
# Makefile — infra-rncp / cloud (OVH Public Cloud)
# Usage local uniquement — le déploiement principal passe par GitHub Actions
# ──────────────────────────────────────────────────────────

SHELL := /bin/bash

# ── Chemins ──────────────────────────────────────────────
VENV           := $(HOME)/.virtualenvs/ansible
ANSIBLE_DIR    := ansible
TERRAFORM_DIR  := terraform
KUBECONFIG     := $(HOME)/.kube/config-ovh

# ── Activation du venv ───────────────────────────────────
ACTIVATE       := source $(VENV)/bin/activate

# ══════════════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════════════

.PHONY: venv pip-install galaxy-install setup

## Créer le virtualenv Python
venv:
	@echo "Création du virtualenv..."
	python3 -m venv $(VENV)
	@echo "Virtualenv créé dans $(VENV)"

## Installer les dépendances Python (Ansible + modules)
pip-install: venv
	@echo "Installation des dépendances Python..."
	$(ACTIVATE) && pip install --upgrade pip
	$(ACTIVATE) && pip install -r $(ANSIBLE_DIR)/requirements.txt
	@echo "Dépendances Python installées"

## Installer les collections Ansible Galaxy
galaxy-install:
	@echo "Installation des collections Ansible..."
	$(ACTIVATE) && ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml
	@echo "Collections Ansible installées"

## Setup complet (venv + pip + galaxy)
setup: pip-install galaxy-install
	@echo ""
	@echo "Setup terminé. Active le venv avec :"
	@echo "   source $(VENV)/bin/activate"

# ══════════════════════════════════════════════════════════
#  TERRAFORM
# ══════════════════════════════════════════════════════════

.PHONY: tf-init tf-plan tf-apply tf-destroy tf-output

## Initialiser Terraform (backend S3 OVH)
tf-init:
	cd $(TERRAFORM_DIR) && terraform init

## Planifier les changements Terraform
tf-plan:
	cd $(TERRAFORM_DIR) && terraform plan

## Appliquer les changements Terraform
tf-apply:
	cd $(TERRAFORM_DIR) && terraform apply

## Détruire l'infrastructure Terraform
tf-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

## Afficher les outputs Terraform
tf-output:
	cd $(TERRAFORM_DIR) && terraform output -json

# ══════════════════════════════════════════════════════════
#  ANSIBLE
# ══════════════════════════════════════════════════════════

.PHONY: inventory ping bootstrap init-cluster install-foundation

## Générer l'inventaire Ansible depuis les outputs Terraform
inventory:
	cd $(TERRAFORM_DIR) && terraform output -json > ../$(ANSIBLE_DIR)/tf_outputs.json
	@echo "Inventaire généré depuis Terraform outputs"

## Tester la connectivité SSH vers les nodes
ping:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible k8s_cluster -i inventory.py -m ping

## Bootstrap des nodes (OS, containerd, kubeadm)
bootstrap:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.py bootstrap-k8s.yml

## Initialiser le cluster (kubeadm init + join)
init-cluster:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.py init-cluster.yml

## Installer les composants fondation
install-foundation:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && KUBECONFIG=$(KUBECONFIG) ansible-playbook -i inventory.py install-foundation.yml

# ══════════════════════════════════════════════════════════
#  KUBERNETES
# ══════════════════════════════════════════════════════════

.PHONY: kubeconfig nodes status check

## Récupérer le kubeconfig depuis le control plane
kubeconfig:
	@mkdir -p $(HOME)/.kube
	scp ubuntu@ovh-cp-01:~/.kube/config $(KUBECONFIG)
	@echo "Kubeconfig récupéré dans $(KUBECONFIG)"
	@echo "   export KUBECONFIG=$(KUBECONFIG)"

## Lister les nodes
nodes:
	KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide

## Statut complet du cluster
status:
	@echo "── Nodes ──────────────────────────────────"
	KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide
	@echo ""
	@echo "── Pods système ───────────────────────────"
	KUBECONFIG=$(KUBECONFIG) kubectl get pods -n kube-system
	@echo ""
	@echo "── Stockage (Cinder CSI) ──────────────────"
	KUBECONFIG=$(KUBECONFIG) kubectl get sc,pv 2>/dev/null || echo "Pas encore configuré"

## Vérification complète du cluster
check:
	@echo "── Nodes ──────────────────────────────────"
	@KUBECONFIG=$(KUBECONFIG) kubectl get nodes
	@echo ""
	@echo "── Applications ArgoCD ─────────────────────"
	@KUBECONFIG=$(KUBECONFIG) kubectl -n argocd get applications
	@echo ""
	@echo "── Certificats TLS ─────────────────────────"
	@KUBECONFIG=$(KUBECONFIG) kubectl get certificate --all-namespaces
	@echo ""
	@echo "── Pods non Running ────────────────────────"
	@KUBECONFIG=$(KUBECONFIG) kubectl get pods --all-namespaces \
		--field-selector=status.phase!=Running,status.phase!=Succeeded | tail -20 \
		|| echo "Tous les pods sont OK"

# ══════════════════════════════════════════════════════════
#  UTILITAIRES
# ══════════════════════════════════════════════════════════

.PHONY: lint clean help

## Linter les playbooks Ansible
lint:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-lint \
		|| echo "ansible-lint non installé, ajoute-le dans requirements.txt"

## Nettoyer les fichiers temporaires
clean:
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -f $(ANSIBLE_DIR)/tf_outputs.json
	@echo "Nettoyé"

## Afficher cette aide
help:
	@echo ""
	@echo "infra-rncp/cloud — Commandes disponibles"
	@echo "══════════════════════════════════════════"
	@echo ""
	@echo "  SETUP"
	@echo "    make setup            Setup complet (venv + pip + galaxy)"
	@echo ""
	@echo "  TERRAFORM"
	@echo "    make tf-init          terraform init (backend S3 OVH)"
	@echo "    make tf-plan          terraform plan"
	@echo "    make tf-apply         terraform apply"
	@echo "    make tf-destroy       terraform destroy"
	@echo "    make tf-output        afficher les outputs JSON"
	@echo ""
	@echo "  ANSIBLE"
	@echo "    make inventory        générer l'inventaire depuis terraform output"
	@echo "    make ping             tester la connectivité SSH"
	@echo "    make bootstrap        bootstrap des nodes K8s"
	@echo "    make init-cluster     initialiser le cluster (kubeadm)"
	@echo "    make install-foundation  installer Cilium, ArgoCD, Cinder CSI..."
	@echo ""
	@echo "  KUBERNETES"
	@echo "    make kubeconfig       récupérer le kubeconfig"
	@echo "    make nodes            lister les nodes"
	@echo "    make status           statut complet du cluster"
	@echo "    make check            vérification complète"
	@echo ""
	@echo "  UTILITAIRES"
	@echo "    make lint             linter les playbooks"
	@echo "    make clean            nettoyer les fichiers temporaires"
	@echo ""
	@echo "  Note : le déploiement principal passe par GitHub Actions."
	@echo "  Voir docs/github-actions.md"
	@echo ""

.DEFAULT_GOAL := help
