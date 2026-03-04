#!/bin/bash

#Run as carplay user

# Define variables
echo "Getting latest LIVI AppImage URL..."
LIVI_URL=$(wget -O - https://api.github.com/repos/f-io/LIVI/releases/latest \
  | grep "browser_download_url" \
  | grep "x86_64.AppImage" \
  | cut -d '"' -f 4)
echo "Starting LIVI Upgrade..."
cd "$HOME/LIVI"
echo "Checking if backup directory exists..."
if [ ! -d "backup" ]; then
    echo "Creating backup directory..."
    mkdir "backup"
fi
echo "Backing up existing LIVI AppImage..."
mv "LIVI.AppImage" backup/
echo "Downloading latest LIVI AppImage..."
wget -qO "LIVI.AppImage" "$LIVI_URL"
echo "Making it executable..."
chmod +x "LIVI.AppImage"
echo -e "$LIVI_URL downloaded and moved into place.\nReboot to run..."
