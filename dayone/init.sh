#!/bin/bash

# --- Function for error handling ---
handle_error() {
  echo -e "\n\n*******************************************************"
  echo "Error: $1"
  echo "*******************************************************"
  exit 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
CODELAB_PROJECT_PREFIX="production-ready-ai"

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

    if gcloud projects create "$RANDOM_PROJECT_ID" --quiet; then
        echo -e "${GREEN}✓ Successfully created project '$RANDOM_PROJECT_ID'.${NC}"
        PROJECT_ID="$RANDOM_PROJECT_ID"
    else
        echo -e "${RED}Auto-creation failed. Falling back to manual selection.${NC}"
        # Fallback: keep trying with new random suffixes until success
        while true; do
            RANDOM_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$MAX_SUFFIX_LEN")
            TARGET_ID="${CODELAB_PROJECT_PREFIX}-${RANDOM_SUFFIX}"

            echo "Attempting to create project with ID: $TARGET_ID..."

            if gcloud projects create "$TARGET_ID" --quiet; then
                echo -e "${GREEN}✓ Successfully created project '$TARGET_ID'.${NC}"
                PROJECT_ID="$TARGET_ID"
                break
            else
                echo -e "${RED}Failed to create '$TARGET_ID'. Retrying with a new ID...${NC}"
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

# --- Part 2: Install Dependencies and Run Billing Setup ---
# This part runs for both existing and newly created projects.
echo -e "\n--- Installing Python dependencies ---"
pip install --upgrade --user google-cloud-billing || handle_error "Failed to install Python libraries."

echo -e "\n--- Running the Billing Enablement Script ---"
python3 billing-enablement.py || handle_error "The billing enablement script failed. See the output above for details."

echo -e "\n--- Full Setup Complete ---"
exit 0
