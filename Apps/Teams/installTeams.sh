#!/bin/bash
#set -x

############################################################################################
##
## Script to download latest Microsoft Teams app for macOS
##
###########################################

## Copyright (c) 2020 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: neiljohn@microsoft.com

# Define variables

tempfile="/tmp/teams.pkg"
weburl="https://go.microsoft.com/fwlink/?linkid=869428"
appname="Microsoft Teams"
log="/var/log/installteams.log"

# function to check if softwareupdate is running to prevent us from installing Rosetta at the same time as another script
isSoftwareUpdateRunning () {

    while ps aux | grep "/usr/sbin/softwareupdate" | grep -v grep; do

        echo "$(date) | [/usr/sbin/softwareupdate] running, waiting..."
        sleep 60

    done

    echo "$(date) | [/usr/sbin/softwareupdate] isn't running, lets carry on"

}

# function to check if we need Rosetta 2
checkForRosetta2 () {

    # Wait here if software update is already running
    isSoftwareUpdateRunning

    echo "$(date) | Checking if we need Rosetta 2 or not"

    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
    if [[ "$processor" == *"Intel"* ]]; then

        echo "$(date) | $processor processor detected, no need to install Rosetta."
        
    else

        echo "$(date) | $processor processor detected, lets see if Rosetta 2 already installed"

        # Check Rosetta LaunchDaemon. If no LaunchDaemon is found,
        # perform a non-interactive install of Rosetta.
        
        if [[ ! -f "/Library/Apple/System/Library/LaunchDaemons/com.apple.oahd.plist" ]]; then
            /usr/sbin/softwareupdate --install-rosetta --agree-to-license
        
            if [[ $? -eq 0 ]]; then
                echo "$(date) | Rosetta has been successfully installed."
            else
                echo "$(date) | Rosetta installation failed!"
                exit 1
            fi
    
        else
            echo "$(date) | Rosetta is already installed. Nothing to do."
        fi
    fi

}

waitForInstaller () {
   while ps aux | grep /System/Library/CoreServices/Installer.app/Contents/MacOS/Installer | grep -v grep; do
   echo "$(date) | Another installer is running, waiting 60s for it to complete"
   sleep 60
   done
   echo "$(date) | Installer not running, safe to start installing"
}

waitForCurl () {
   while ps aux | grep curl | grep -v grep; do
   echo "$(date) | Another instance of Curl is running, waiting 60s for it to complete"
   sleep 60
   done
   echo "$(date) | No Curl's running, let's start our download"
}

# start logging

exec 1>> $log 2>&1

# Begin Script Body

echo ""
echo "##############################################################"
echo "# $(date) | Starting install of $appname"
echo "############################################################"
echo ""

# Lets see if we need Rosetta
checkForRosetta2

# Let's download the files we need and attempt to install...

echo "$(date) | Downloading $appname"
waitForCurl
curl -L -f -o $tempfile $weburl

waitForInstaller
echo "$(date) | Installing $appname"
installer -dumplog -pkg $tempfile -target /Applications
if [ "$?" = "0" ]; then
   echo "$(date) | $appname Installed"
   echo "$(date) | Cleaning Up"
   rm -rf $tempfile
   exit 0
else
  # Something went wrong here, either the download failed or the install Failed
  # intune will pick up the exit status and the IT Pro can use that to determine what went wrong.
  # Intune can also return the log file if requested by the admin
   echo "$(date) | Failed to install $appname"
   exit 1
fi
