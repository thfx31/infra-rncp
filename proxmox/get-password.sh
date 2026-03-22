#!/bin/bash
# get-passwords.sh — Affiche les mots de passe initiaux des services
# Usage : ./get-passwords.sh ou make passwords

set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-poc}"
export KUBECONFIG

echo "══════════════════════════════════════════"
echo "  Mots de passe initiaux des services"
echo "══════════════════════════════════════════"
echo ""

# ArgoCD
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "N/A")
echo "  ArgoCD    : https://argocd.k8s.thfx.fr"
echo "  Login     : admin / ${ARGOCD_PASS}"
echo ""

# Harbor
echo "  Harbor    : https://harbor.k8s.thfx.fr"
echo "  Login     : admin / Ch4ng3M3!"
echo ""

# GitLab
GITLAB_PASS=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "N/A")
echo "  GitLab    : https://gitlab.k8s.thfx.fr"
echo "  Login     : root / ${GITLAB_PASS}"
echo ""

# Jenkins
JENKINS_PASS=$(kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' 2>/dev/null | base64 -d || echo "N/A")
echo "  Jenkins   : https://jenkins.k8s.thfx.fr"
echo "  Login     : admin / ${JENKINS_PASS}"
echo ""

# SonarQube
echo "  SonarQube : https://sonarqube.k8s.thfx.fr"
echo "  Login     : admin / admin (changement au 1er login)"
echo ""
echo ""

# Grafana
echo "  Grafana   : https://grafana.k8s.thfx.fr"
echo "  Login     : admin / Ch4ng3M3!"
echo ""
echo "══════════════════════════════════════════"