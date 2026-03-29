#!/bin/bash
set -e

# Run this after installing a minimal debian 13 with only standard system utilities and SSH server.
# Be sure to create user "carplay" during install.

# Define variables
CARPLAY_USER="carplay"
CARPLAY_USER_ID=$(getent passwd "$CARPLAY_USER" | cut -d: -f3)
CARPLAY_USER_HOME=$(getent passwd "$CARPLAY_USER" | cut -d: -f6)
LIVI_SERVICE_FILE="/etc/systemd/system/livi.service"
RULE_FILE="/etc/udev/rules.d/99-LIVI.rules"
GRUB_FILE="/etc/default/grub"
KERNEL_PRINTK_FILE="/etc/sysctl.d/20-quiet-printk.conf"
GRUBD_FILE_10="/etc/grub.d/10_linux"

# Check if carplay user exists, exit if it doesn't.
echo "Ensuring carplay user exists..."
if ! id "$CARPLAY_USER" >/dev/null 2>&1; then
  echo "User $CARPLAY_USER does not exist."
  exit 1
fi

# Install required packages
echo "Installing required packages..."
apt update && apt install -y -qq --no-install-recommends \
  cron wget sudo ca-certificates \
  linux-image-amd64 firmware-linux \
  libinput10 wayland-protocols \
  cage foot acpi mesa-vulkan-drivers \
  mesa-utils xserver-xorg-input-libinput \
  fuse libfuse2t64 libnspr4 libnss3 \
  libatk1.0-0t64 libatk-bridge2.0-0t64 \
  libcups2t64 libcairo2 libgtk-3-0t64 \
  libinput-tools wlr-randr libinput-bin \
  libasound2

# Add carplay user to sudo group
echo "Adding $CARPLAY_USER to sudo group..."
usermod -aG sudo $CARPLAY_USER

# Create systemd service file
echo "Creating systemd service file..."
cat <<EOF > "$LIVI_SERVICE_FILE"
[Unit]
Description=LIVI CarPlay
After=systemd-user-sessions.service
Conflicts=getty@tty1.service

[Service]
User=$CARPLAY_USER
PAMName=login
WorkingDirectory=$CARPLAY_USER_HOME/LIVI
Environment=HOME=$CARPLAY_USER_HOME
Environment=XDG_RUNTIME_DIR=/run/user/$CARPLAY_USER_ID

TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
StandardInput=tty
StandardOutput=tty
StandardError=journal

ExecStart=/usr/bin/cage $CARPLAY_USER_HOME/LIVI/LIVI.AppImage
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Disabing getty and enabling LIVI systemd service..."
sudo systemctl disable getty@tty1.service
sudo systemctl enable livi.service

# Create LIVI dir and download LIVI AppImage.
echo "Downloading latest LIVI AppImage..."
LIVI_URL=$(wget -O - https://api.github.com/repos/f-io/LIVI/releases/latest \
  | grep "browser_download_url" \
  | grep "x86_64.AppImage" \
  | cut -d '"' -f 4)
sudo -u "$CARPLAY_USER" mkdir -p "$CARPLAY_USER_HOME/LIVI"
sudo -u "$CARPLAY_USER" wget -O "$CARPLAY_USER_HOME/LIVI/LIVI.AppImage" "$LIVI_URL"
sudo -u "$CARPLAY_USER" chmod +x "$CARPLAY_USER_HOME/LIVI/LIVI.AppImage"

# Set udev rules for dongle and disabling the trackpad
echo "Creating udev rules for dongle and Touchpad."
echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1314\", ATTR{idProduct}==\"152*\", MODE=\"0660\", OWNER=\"$CARPLAY_USER\"" > "$RULE_FILE"
cat <<'EOF' >> "$RULE_FILE"
ATTRS{name}=="*Touchpad*", ENV{LIBINPUT_IGNORE_DEVICE}="1"
ATTRS{name}=="*Mouse*", ENV{LIBINPUT_IGNORE_DEVICE}="1"
EOF
udevadm control --reload-rules
udevadm trigger

# Reduce boot time and screen clutter by tweaking grub
echo "Tweaking grub, etc for quicker and cleaner boot..."
# Set GRUB_TIMEOUT=0
if grep -q "^GRUB_TIMEOUT=" "$GRUB_FILE"; then
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"
else
    echo 'GRUB_TIMEOUT=0' >> "$GRUB_FILE"
fi

# Set GRUB_CMDLINE_LINUX_DEFAULT
NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=1 vt.global_cursor_default=0 systemd.show_status=false rd.udev.log_level=3 nowatchdog mitigations=off video=efifb:nobgrt console=tty3"'
if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE"; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$NEW_CMDLINE|" "$GRUB_FILE"
else
    echo "$NEW_CMDLINE" >> "$GRUB_FILE"
fi
echo 'GRUB_TIMEOUT_STYLE=hidden' >> "$GRUB_FILE"

# Ensure GRUB_TERMINAL=console is set in $GRUB_FILE
if grep -qE '^[[:space:]]*#?[[:space:]]*GRUB_TERMINAL=' "$GRUB_FILE"; then
    # Replace existing (commented or not) line
    sed -i 's|^[[:space:]]*#\?[[:space:]]*GRUB_TERMINAL=.*|GRUB_TERMINAL=console|' "$GRUB_FILE"
else
    # Add it to the end of the file
    echo 'GRUB_TERMINAL=console' >> "$GRUB_FILE"
fi

sed -i 's/quiet_boot="0"/quiet_boot="1"/g' "$GRUBD_FILE_10"
echo "kernel.printk = 3 3 3 3" > "$KERNEL_PRINTK_FILE"

update-grub

# more screen clutter removal
echo "Clearing MOTD..."
> /etc/motd
rm /etc/update-motd.d/10-uname

# Create power monitor script
echo "Creating power monitor script..."
touch /root/power-monitor.sh
chmod +x /root/power-monitor.sh

cat <<'EOF' > "/root/power-monitor.sh"
#!/bin/bash

ACPI_CMD="/usr/bin/acpi"
SHUTDOWN_SECS="5"
RECHECK_SECS="2"

# Loop to check power status
while true; do
    # Get uptime
    UPTIME_SECS=$(cut -d. -f1 /proc/uptime)

    # Get the adapter status
    STATUS=$($ACPI_CMD -a)

    # Check if the tablet is plugged in (AC connected)
    if [[ "$STATUS" != *"on-line"* ]]; then
        # If not plugged in, initiate shutdown
        echo "AC adapter is unplugged."
        if [[ $UPTIME_SECS -ge 300 ]]; then
            echo "Initiating shutdown in $SHUTDOWN_SECS seconds..."
            sleep $SHUTDOWN_SECS
            /sbin/shutdown -P now
            exit 0
        fi
        echo "Uptime under 5 minutes, staying on in case you booted up unplugged."
        echo "Disabling auto-shutdown."
        exit 0
    fi

    if [[ "$STATUS" == *"on-line"* ]]; then
        echo "AC adapter is plugged in.  Checking again in $RECHECK_SECS seconds."
    fi
    # Sleep for X seconds before checking again
    sleep $RECHECK_SECS
done
EOF

# Add power monitor cron job
echo "Creating power monitor cron job..."
CRON_CMD="/root/power-monitor.sh"
CRON_JOB="@reboot $CRON_CMD"

EXISTING_CRON=$(crontab -l -u root 2>/dev/null || true)

if ! echo "$EXISTING_CRON" | grep -Fq "$CRON_CMD"; then
    printf "%s\n%s\n" "$EXISTING_CRON" "$CRON_JOB" | crontab -u root -
    echo "Cron job added."
else
    echo "Cron job already exists."
fi

echo "Done setting up LIVI embedded tablet!  Reboot to load LIVI."
