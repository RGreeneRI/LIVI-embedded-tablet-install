# LIVI-embedded-tablet-install
A script to set up an embedded LIVI x86_64 tablet from a clean Debian minimal install.

# Note
This was tested on a Dell Latitude 7200 2in1 tablet.  Audio is not configured as I use the "Disable Audio" option in LIVI settings.  I instead use the car bluetooth for audio as the mic in my tablet is unusable in a car.  THis also allows me to use steering wheel controls for changing tracks.

# System Prep
Install debian using the netinstall image.  I used "debian-13.3.0-amd64-netinst.iso"  During setup, connect to your wifi so it saves the wifi config to the installed system.  This will be the only way to connect to the system via SSH once complete.  No local config will be possible after running the script, as you will be locked into LIVI.  Deselect "Debian dekstop environment" and "GNOME".  Select SSH Server and "Standard System Utilities" only.  

# Installation
Run this script logged in as root, when complete reboot.  

# After install
It should boot straight to LIVI showing none of the usual linux boot process, and require NO login.  Don't install this on anything but a dedicated tablet for LIVI, as it will make the computer/tablet useless for anything else.
