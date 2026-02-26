#!/bin/bash
#
# Way Back Home - Setup Script
#
# This script connects you to the Way Back Home rescue network
# and reserves your explorer identity.
#
# Run from project root: ./scripts/setup.sh
#

set -e

# Determine project root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Step -1: Cleanup Old Experiments
# =============================================================================
echo "Cleaning up lab environments..."
rm -rf ~/prai-roadshow-lab-1-starter 2>/dev/null || true
rm -rf ~/agent-evaluation-lab 2>/dev/null || true
rm -rf ~/prai-roadshow-lab-3-starter 2>/dev/null || true

if command -v uv &> /dev/null; then
    echo "Clearing uv cache..."
    uv cache clean
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


# Print banner
echo ""
echo -e "${CYAN}🚀 Welcome to Way Back Home!${NC}"
echo ""

# =============================================================================
# Step 0: Check Google Cloud Authentication
# =============================================================================
echo "Checking Google Cloud authentication..."

if ! gcloud auth print-access-token > /dev/null 2>&1; then
    echo -e "${RED}Error: Not authenticated with Google Cloud.${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}✓ Authenticated${NC}"

# =============================================================================
# Step 1: Find or Create Google Cloud Project
# =============================================================================
PROJECT_FILE="$HOME/project_id.txt"
PROJECT_ID=""
CODELAB_PROJECT_PREFIX="waybackhome"

# 1a. Check for existing project with prefix
echo "Searching for existing projects with prefix '$CODELAB_PROJECT_PREFIX'..."
EXISTING_PROJECT=$(gcloud projects list --filter="projectId:$CODELAB_PROJECT_PREFIX*" --format="value(projectId)" --limit=1 2>/dev/null)

if [ -n "$EXISTING_PROJECT" ]; then
    echo -e "${YELLOW}Found an existing project: ${CYAN}${EXISTING_PROJECT}${NC}"
    read -p "Do you want to reuse this project? (y/N): " REUSE_CHOICE
    if [[ "$REUSE_CHOICE" =~ ^[Yy]$ ]]; then
        PROJECT_ID="$EXISTING_PROJECT"
        echo -e "${GREEN}✓ Reusing project '$PROJECT_ID'.${NC}"
    fi
fi

# 1b. Interactive project creation if no project found or user declined reuse
if [ -z "$PROJECT_ID" ]; then
    # Delete existing project file to ensure a clean state for a new project
    rm -f "$PROJECT_FILE"

    echo ""
    echo -e "${YELLOW}Let's set a new project.${NC}"
    PREFIX_LEN=${#CODELAB_PROJECT_PREFIX}
    MAX_SUFFIX_LEN=$(( 30 - PREFIX_LEN - 1 ))
    RANDOM_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$MAX_SUFFIX_LEN")
    RANDOM_PROJECT_ID="${CODELAB_PROJECT_PREFIX}-${RANDOM_SUFFIX}"

    echo -e "Creating project: ${CYAN}${RANDOM_PROJECT_ID}${NC}"

    if gcloud projects create "$RANDOM_PROJECT_ID" --labels=environment=development --quiet; then
        echo -e "${GREEN}✓ Successfully created project '$RANDOM_PROJECT_ID'.${NC}"
        PROJECT_ID="$RANDOM_PROJECT_ID"
    else
        echo -e "${RED}Auto-creation failed. Falling back to manual selection.${NC}"
        # Fallback: let user pick or retry
        while true; do
            RANDOM_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$MAX_SUFFIX_LEN")
            SUGGESTED_ID="${CODELAB_PROJECT_PREFIX}-${RANDOM_SUFFIX}"

            echo ""
            echo "Select a Project ID:"
            echo "  1. Press Enter to CREATE a new project: $SUGGESTED_ID"
            echo "  2. Or type an existing Project ID to use."
            read -p "Project ID: " USER_INPUT

            TARGET_ID="${USER_INPUT:-$SUGGESTED_ID}"

            if [ -z "$TARGET_ID" ]; then
                echo -e "${RED}Project ID cannot be empty.${NC}"
                continue
            fi

            echo "Checking status of '$TARGET_ID'..."

            if gcloud projects describe "$TARGET_ID" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Project '$TARGET_ID' exists and is accessible.${NC}"
                PROJECT_ID="$TARGET_ID"
                break
            else
                echo "Project '$TARGET_ID' not found. Attempting to create..."
                if gcloud projects create "$TARGET_ID" --labels=environment=development --quiet; then
                    echo -e "${GREEN}✓ Successfully created project '$TARGET_ID'.${NC}"
                    PROJECT_ID="$TARGET_ID"
                    break
                else
                    echo -e "${RED}Failed to create '$TARGET_ID'. Please try a different ID.${NC}"
                fi
            fi
        done
    fi
fi

gcloud config set project "$PROJECT_ID" --quiet || {
    echo -e "${RED}Failed to set active project.${NC}"
    exit 1
}

# Save project ID for reuse across levels
echo "$PROJECT_ID" > "$PROJECT_FILE"
echo -e "Using project: ${CYAN}${PROJECT_ID}${NC}"

# =============================================================================
# Step 2: Check and Enable Billing (NEW!)
# =============================================================================
echo ""
echo -e "${YELLOW}Checking billing configuration...${NC}"

# Pre-install billing library (needed by billing-enablement.py)
pip install --quiet --user google-cloud-billing 2>/dev/null || true

# Run the billing enablement script
if ! python3 "${SCRIPT_DIR}/billing-enablement.py"; then
    echo ""
    echo -e "${RED}Billing setup incomplete. Please configure billing and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Setup complete! Ready to proceed with the codelab instructions.${NC}"
