#!/bin/bash
# Deploy Lead Management app to Firebase Hosting
# Run this on your Mac: bash deploy_to_firebase.sh

set -e

echo "=== Lead Management - Firebase Hosting Deploy ==="
echo ""

# Check if firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Login to Firebase (opens browser)
echo "Logging into Firebase..."
firebase login

# Deploy to Firebase Hosting
echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting --project leadmanagement-8aca6

echo ""
echo "=== Deployment Complete! ==="
echo "Your app is now live at: https://leadmanagement-8aca6.web.app"
