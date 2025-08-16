#!/bin/bash
echo "[INFO] Starting Universal Deploy Script..."

# Step 1: Find the first available deploy script
TARGET_SCRIPT=$(ls deploy-*.sh 2>/dev/null | head -n 1)

if [ -z "$TARGET_SCRIPT" ]; then
echo "[ERROR] No deploy-*.sh file found in this folder."
exit 1
fi

echo "[INFO] Found deploy script: $TARGET_SCRIPT"

# Step 2: Make it executable
chmod +x "$TARGET_SCRIPT"

# Step 3: Run the script
./"$TARGET_SCRIPT"

echo "[INFO] Universal deployment complete."