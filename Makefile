# ──────────────────────────────────────────────────────────
# Makefile — infra-rncp
# Pilotage Ansible & Terraform depuis la machine de dev
# ──────────────────────────────────────────────────────────

SHELL := /bin/bash

# ── Chemins ──────────────────────────────────────────────
VENV           := $(HOME)/.virtualenvs/ansible
ANSIBLE_DIR    := ansible
TERRAFORM_DIR  := terraform
KUBECONFIG     := $(HOME)/.kube/config-poc

# ── Activation du venv ───────────────────────────────────
ACTIVATE       := source $(VENV)/bin/activate

# ══════════════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════════════

.PHONY: venv pip-install galaxy-install setup

## Créer le virtualenv Python
venv:
	@echo "🐍 Création du virtualenv..."
	python3 -m venv $(VENV)
	@echo "✅ Virtualenv créé dans $(VENV)"

## Installer les dépendances Python (Ansible + modules)
pip-install: venv
	@echo "📦 Installation des dépendances Python..."
	$(ACTIVATE) && pip install --upgrade pip
	$(ACTIVATE) && pip install -r $(ANSIBLE_DIR)/requirements.txt
	@echo "✅ Dépendances Python installées"

## Installer les collections Ansible Galaxy
galaxy-install:
	@echo "📦 Installation des collections Ansible..."
	$(ACTIVATE) && ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml
	@echo "✅ Collections Ansible installées"

## Setup complet (venv + pip + galaxy)
setup: pip-install galaxy-install
	@echo ""
	@echo "🎉 Setup terminé. Active le venv avec :"
	@echo "   source $(VENV)/bin/activate"

# ══════════════════════════════════════════════════════════
#  ANSIBLE
# ══════════════════════════════════════════════════════════

.PHONY: ping bootstrap init-cluster install-foundation

## Tester la connectivité SSH vers les nodes
ping:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible k8s_cluster -m ping

## Bootstrap des nodes (OS, sécurité, containerd, kubeadm)
bootstrap:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-playbook bootstrap-k8s.yml

## Initialiser le cluster (kubeadm init + join)
init-cluster:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-playbook init-cluster.yml

## Installer les composants fondation (Cilium, Longhorn...)
install-foundation:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && KUBECONFIG=$(KUBECONFIG) ansible-playbook install-foundation.yml -e @secrets.yml

# ══════════════════════════════════════════════════════════
#  TERRAFORM
# ══════════════════════════════════════════════════════════

.PHONY: tf-init tf-plan tf-apply tf-destroy tf-output

## Initialiser Terraform
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
	cd $(TERRAFORM_DIR) && terraform output

# ══════════════════════════════════════════════════════════
#  KUBERNETES
# ══════════════════════════════════════════════════════════

.PHONY: kubeconfig nodes status check

## Récupérer le kubeconfig depuis le control plane
kubeconfig:
	@mkdir -p $(HOME)/.kube
	scp admintf@rncp-cp-01:~/.kube/config $(KUBECONFIG)
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
	@echo "── Stockage ───────────────────────────────"
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
	@KUBECONFIG=$(KUBECONFIG) kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded | tail -20 || echo "Tous les pods sont OK"
	@echo ""
	@echo "── Mots de passe ───────────────────────────"
	@KUBECONFIG=$(KUBECONFIG) bash get-password.sh

# ══════════════════════════════════════════════════════════
#  UTILITAIRES
# ══════════════════════════════════════════════════════════

.PHONY: lint clean help

## Linter les playbooks Ansible
lint:
	$(ACTIVATE) && cd $(ANSIBLE_DIR) && ansible-lint || echo "ansible-lint non installé, ajoute-le dans requirements.txt"

## Nettoyer les fichiers temporaires
clean:
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Nettoyé"

## Afficher cette aide
help:
	@echo ""
	@echo "infra-rncp — Commandes disponibles"
	@echo "══════════════════════════════════════════"
	@echo ""
	@echo "  SETUP"
	@echo "    make setup            Setup complet (venv + pip + galaxy)"
	@echo "    make venv             Créer le virtualenv"
	@echo "    make pip-install      Installer les dépendances Python"
	@echo "    make galaxy-install   Installer les collections Ansible"
	@echo ""
	@echo "  ANSIBLE"
	@echo "    make ping             Tester la connectivité SSH"
	@echo "    make bootstrap        Bootstrap des nodes K8s"
	@echo "    make init-cluster     Initialiser le cluster (kubeadm)"
	@echo "    make install-foundation  Installer Cilium, Longhorn..."
	@echo ""
	@echo "  TERRAFORM"
	@echo "    make tf-init          terraform init"
	@echo "    make tf-plan          terraform plan"
	@echo "    make tf-apply         terraform apply"
	@echo "    make tf-destroy       terraform destroy"
	@echo "    make tf-output        terraform output"
	@echo ""
	@echo "  KUBERNETES"
	@echo "    make kubeconfig       Récupérer le kubeconfig"
	@echo "    make nodes            Lister les nodes"
	@echo "    make status           Statut complet du cluster"
	@echo ""
	@echo "  UTILITAIRES"
	@echo "    make lint             Linter les playbooks"
	@echo "    make clean            Nettoyer les fichiers temporaires"
	@echo ""

.DEFAULT_GOAL := help