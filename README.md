# wifi-sniffer_meep

Key Improvements:
Automatic Dependency Installation:

Checks for required packages (aircrack-ng, tshark, wireless-tools, iw)

Installs any missing packages automatically

Verifies successful installation before proceeding

Better Error Handling:

Checks if package installation was successful

Verifies network interface exists before attempting monitor mode

Maintained All Original Functionality:

Same monitoring and probing capabilities as before

Still supports all command-line options

Cleaner Output:

More informative messages about what's happening during setup

Usage Remains the Same:
bash
sudo ./wifi_sniffer.sh [options]
The script will now automatically install any missing dependencies when run for the first time. Subsequent runs will skip the installation if all packages are already present.
