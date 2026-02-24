#!/bin/bash
# =============================================================================
# gitlab-init.sh
#
# Initialise le projet firmware-poc sur GitLab après déploiement du cluster.
# - Récupère le mot de passe root depuis le secret Kubernetes
# - Crée un token d'accès via l'API
# - Crée le groupe et le projet
# - Clone les sources depuis GitHub et les pousse sur GitLab
#
# Usage :
#   ./gitlab-init.sh
#
# Prérequis :
#   - kubectl configuré (KUBECONFIG pointant vers le cluster)
#   - curl, git, base64 installés
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-poc}"
export KUBECONFIG

GITLAB_URL="https://gitlab.k8s.thfx.fr"
GITLAB_GROUP="poc-ci"
GITLAB_PROJECT="firmware-poc"
GITLAB_DEFAULT_BRANCH="main"

# Dépôt GitHub contenant les sources du firmware
GITHUB_REPO="https://github.com/thfx31/infra-rncp.git"
# Chemin relatif dans le dépôt GitHub où se trouve le code C
FIRMWARE_SRC_PATH="docker/firmware-poc"

# Délai max d'attente GitLab (secondes)
WAIT_TIMEOUT=600
WAIT_INTERVAL=15

# --- Couleurs ----------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${GREEN}==>${NC} $*"; }

# --- Fonctions ---------------------------------------------------------------

wait_for_gitlab() {
    step "Waiting for GitLab to be ready..."
    local elapsed=0

    until curl -sk --max-time 5 "${GITLAB_URL}/-/readiness" | grep -q '"ok"' 2>/dev/null; do
        if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
            error "GitLab did not become ready after ${WAIT_TIMEOUT}s. Aborting."
        fi
        info "GitLab not ready yet, retrying in ${WAIT_INTERVAL}s... (${elapsed}s elapsed)"
        sleep "$WAIT_INTERVAL"
        elapsed=$((elapsed + WAIT_INTERVAL))
    done

    info "GitLab is up. Waiting 15s for API initialization..."
    sleep 15
}

get_root_password() {
    step "Retrieving GitLab root password from Kubernetes secret..."

    GITLAB_ROOT_PASSWORD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
        -o jsonpath='{.data.password}' | base64 -d)

    if [ -z "$GITLAB_ROOT_PASSWORD" ]; then
        error "Could not retrieve GitLab root password from secret."
    fi

    info "Root password retrieved successfully."
}

create_api_token() {
    step "Creating GitLab API token via Rails runner..."

    # GitLab ne permet pas de créer un PAT via l'API avec login/password directement.
    # On utilise l'API de session pour obtenir un token temporaire (OAuth Resource Owner).
    local response
    response=$(curl -sk --request POST "${GITLAB_URL}/oauth/token" \
        --data "grant_type=password" \
        --data "username=root" \
        --data-urlencode "password=${GITLAB_ROOT_PASSWORD}")

    GITLAB_TOKEN=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)

    if [ -z "$GITLAB_TOKEN" ]; then
        error "Could not obtain API token. Response: $response"
    fi

    info "API token obtained."
}

gitlab_api() {
    # Wrapper curl pour l'API GitLab
    # Usage : gitlab_api GET /api/v4/groups
    local method="$1"
    local endpoint="$2"
    shift 2
    curl -sk --request "$method" "${GITLAB_URL}${endpoint}" \
        --header "Authorization: Bearer ${GITLAB_TOKEN}" \
        --header "Content-Type: application/json" \
        "$@"
}

create_group() {
    step "Creating GitLab group '${GITLAB_GROUP}'..."

    local status
    status=$(gitlab_api GET "/api/v4/groups/${GITLAB_GROUP}" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || true)

    if [ -n "$status" ]; then
        info "Group '${GITLAB_GROUP}' already exists (id=${status}), skipping."
        GITLAB_GROUP_ID="$status"
        return
    fi

    local response
    response=$(gitlab_api POST "/api/v4/groups" \
        --data "{\"name\":\"${GITLAB_GROUP}\",\"path\":\"${GITLAB_GROUP}\",\"visibility\":\"private\"}")

    GITLAB_GROUP_ID=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    info "Group created (id=${GITLAB_GROUP_ID})."
}

create_project() {
    step "Creating GitLab project '${GITLAB_PROJECT}'..."

    local project_path="${GITLAB_GROUP}%2F${GITLAB_PROJECT}"
    local status
    status=$(gitlab_api GET "/api/v4/projects/${project_path}" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || true)

    if [ -n "$status" ]; then
        info "Project '${GITLAB_GROUP}/${GITLAB_PROJECT}' already exists (id=${status}), skipping creation."
        GITLAB_PROJECT_ID="$status"
        return
    fi

    local response
    response=$(gitlab_api POST "/api/v4/projects" \
        --data "{
            \"name\": \"${GITLAB_PROJECT}\",
            \"path\": \"${GITLAB_PROJECT}\",
            \"namespace_id\": ${GITLAB_GROUP_ID},
            \"visibility\": \"private\",
            \"default_branch\": \"${GITLAB_DEFAULT_BRANCH}\",
            \"initialize_with_readme\": false
        }")

    GITLAB_PROJECT_ID=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    info "Project created (id=${GITLAB_PROJECT_ID})."
}

push_firmware_code() {
    step "Pushing firmware source code to GitLab..."

    # Vérifier si le projet a déjà des commits
    local commits
    commits=$(gitlab_api GET "/api/v4/projects/${GITLAB_PROJECT_ID}/repository/commits?per_page=1" | \
        python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "$commits" -gt 0 ]; then
        info "Project already has commits, skipping push."
        return
    fi

    # Dossier temporaire
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT

    info "Cloning infra-rncp from GitHub..."
    git clone --depth=1 --quiet "$GITHUB_REPO" "${tmpdir}/infra-rncp"

    if [ ! -d "${tmpdir}/infra-rncp/${FIRMWARE_SRC_PATH}" ]; then
        error "Firmware source path '${FIRMWARE_SRC_PATH}' not found in infra-rncp."
    fi

    info "Preparing firmware-poc repository..."
    cp -r "${tmpdir}/infra-rncp/${FIRMWARE_SRC_PATH}" "${tmpdir}/firmware-poc"

    cd "${tmpdir}/firmware-poc"
    git init --quiet
    git config user.email "ci-init@poc.local"
    git config user.name "CI Init"
    git checkout -b "${GITLAB_DEFAULT_BRANCH}" --quiet

    git add .
    git commit -m "feat: initial firmware-poc — CI/CD POC" --quiet

    # Token encodé dans l'URL (masqué dans le set -x si activé)
    local remote_url
    remote_url="${GITLAB_URL/https:\/\//https://root:${GITLAB_ROOT_PASSWORD}@}/${GITLAB_GROUP}/${GITLAB_PROJECT}.git"
    git remote add origin "$remote_url"
    git push -u origin "${GITLAB_DEFAULT_BRANCH}" --quiet

    info "Code pushed successfully to ${GITLAB_URL}/${GITLAB_GROUP}/${GITLAB_PROJECT}"
    cd - > /dev/null
}

print_summary() {
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  GitLab initialization complete${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo "  Project : ${GITLAB_URL}/${GITLAB_GROUP}/${GITLAB_PROJECT}"
    echo "  Branch  : ${GITLAB_DEFAULT_BRANCH}"
    echo ""
    echo "  Next step: configure Jenkins webhook"
    echo ""
}

# --- Main --------------------------------------------------------------------

echo ""
echo "=============================================="
echo "  gitlab-init.sh — POC CI/CD"
echo "=============================================="

wait_for_gitlab
get_root_password
create_api_token
create_group
create_project
push_firmware_code
print_summary