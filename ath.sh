#!/bin/bash

# Global Vars
DIALOG_TITLE="All The Hacks"
ATH_DIR="$HOME/allthehacks/"
DEFAULT_CONFIG_URL="https://raw.githubusercontent.com/yamamushi/all-the-hacks/master/config.json"
PACKAGE_MANAGER='unknown'
PLATFORM='unknown'
MISSING_DEPENDENCIES=""
URL_OPENER='unknown'

# Parse command line options
# -c <config file> (default is $HOME/allthehacks/config.json)
# -d <directory> (default is $HOME/allthehacks/)
# -h <help>
function ParseCommandLineOptions() {
  local OPTION
  while getopts "d:h" OPTION; do
      case $OPTION in
          d)
              ATH_DIR=$OPTARG
              ;;
          h)
              echo "Usage: ath.sh [-c <config file>]"
              exit 0
              ;;
          *)
              echo "Unrecognized option: $OPTARG, try -h for help"
              exit 1
              ;;
      esac
  done
}

####################
# Pre-Setup Checks #
####################

# Determine OS
function CheckOSType() {
  local UNAME_STRING
  UNAME_STRING=$(uname)
  if [[ "$UNAME_STRING" == 'Linux' ]]; then
     PLATFORM='linux'
  elif [[ "$UNAME_STRING" == 'Darwin' ]]; then
     PLATFORM='osx'
  fi
}

# Setup Package Manager (apt-get, yum, etc)
function SetupPackageManager() {
  if [[ $PLATFORM == 'linux' ]]; then
  # If linux, we need to determine the distro to determine the package manager
    if type lsb_release >/dev/null 2>&1; then
        # If OS == Ubuntu, we use apt-get
        if [ "$OS" == 'Ubuntu' ]; then
          PACKAGE_MANAGER='apt-get'
        fi
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        PACKAGE_MANAGER='apt'
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        PACKAGE_MANAGER='apt'
    elif [ -f /etc/redhat-release ]; then
        PACKAGE_MANAGER='yum'
    else
        PACKAGE_MANAGER='unknown'
    fi
  elif [[ $PLATFORM == 'osx' ]]; then
    # Check to see if command line tools are installed, if not prompt to install
    if ! type -p gcc >/dev/null 2>&1; then
      echo "Error: XCode Command line tools are not installed. Please install XCode Command Line Tools as follows and try again." >&2
      echo "Run: xcode-select --install"
      exit 1
    fi

    # Check to see if brew is installed
    if ! [ -x "$(command -v brew)" ]; then
      echo "Error: Homebrew is not installed. Visit https://brew.sh/ for installation instructions." >&2
      exit 1
    else
      PACKAGE_MANAGER='brew'
    fi
  fi

  # If PACKAGE_MANAGER is unknown, we can't continue
  if [[ $PACKAGE_MANAGER == 'unknown' ]]; then
    echo "Error: Unable to determine appropriate package manager for $PLATFORM"
    exit 1
  fi
}

# Check to see if all the dependencies are installed, and add to the MISSING_DEPENDENCIES string if not
function SetupDependencyList() {
  # Check to see if jq is installed
  if ! [ -x "$(command -v jq)" ]; then
    # append jq to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES jq"
  fi

  # Check to see if telnet is installed
  if ! [ -x "$(command -v telnet)" ]; then
    # append telnet to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES telnet"
  fi

  # Check to see if ssh is installed
  if ! [ -x "$(command -v ssh)" ]; then
    # append ssh to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES ssh"
  fi

  # Check to see if git is installed
  if ! [ -x "$(command -v git)" ]; then
    # append git to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES git"
  fi

  # Check to see if gcc is installed
  if ! [ -x "$(command -v gcc)" ]; then
    # append gcc to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES gcc"
  fi

  # Check to see if curl is installed
  if ! [ -x "$(command -v curl)" ]; then
    # append curl to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES curl"
  fi

  # Check to see if dialog is installed
  if ! [ -x "$(command -v dialog)" ]; then
    # append dialog to MISSING_DEPENDENCIES
    MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES dialog"
  fi

  # If platform is osx set URL_OPENER to open command, otherwise check for xdg-open command if linux
  if [[ $PLATFORM == 'osx' ]]; then
    URL_OPENER="open"
  else
    if ! [ -x "$(command -v xdg-open)" ]; then
      MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES xdg-open"
    else
      URL_OPENER="xdg-open"
    fi
  fi
}

# Check to see if all the dependencies are installed, and if not, prompt to install
function InstallDependencies() {
  # If MISSING_DEPENDENCIES is not empty, we need to install the missing dependencies
  if [[ -n $MISSING_DEPENDENCIES ]]; then
    echo "Missing Dependencies: $MISSING_DEPENDENCIES"
    echo "Would you like to install them now? (y/n)"
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if [[ $PACKAGE_MANAGER == 'apt-get' ]]; then
        # If package installation fails we exit with a message to the user
        sudo apt-get install "$MISSING_DEPENDENCIES" || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'apt' ]]; then
        sudo apt install "$MISSING_DEPENDENCIES" || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'yum' ]]; then
        sudo yum install "$MISSING_DEPENDENCIES" || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'brew' ]]; then
        brew install "$MISSING_DEPENDENCIES" || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
    fi
    else
      echo "Please install the missing dependencies and try again."
      exit 1
    fi

  fi
}

# Download the default config files from GitHub
function RetrieveDefaultConfig() {
  # If the config file does not exist, we need to download it
  if [[ ! -f "$ATH_DIR/config.json" ]]; then
    curl -s -o "$ATH_DIR/config.json" "$DEFAULT_CONFIG_URL" || { echo "Error: Unable to download config file. Please check your internet connection and try again."; exit 1; }
  fi
}

function CheckForAthDir() {
  local  __resultvar=$1
   # Check to see if .allthehacks directory is present, and if not, prompt whether to create it
  if [ ! -d "$ATH_DIR" ]; then

    # Ask user if they want to create the directory
    dialog --title "$DIALOG_TITLE" --yesno "An installation was not found, would you like to create the $ATH_DIR directory and download the default configs?" 8 60
    if [ $? -eq 0 ]; then
      # Create the directory
      mkdir "$ATH_DIR"
      RetrieveDefaultConfig
      eval $__resultvar="newinstall" # Return 0 to indicate that a new installation was created
    else
      # Exit the script
      echo "Error: Config directory ($ATH_DIR) not found, aborting"
      exit 1
    fi
  fi
  eval $__resultvar="nonewinstall" # Return 1 to indicate that the directory exists, but we did not check for a config
}

# Setup our installation directory and configuration if they don't exist
function SetupInstallation() {
  local SETUP_STATUS
  CheckForAthDir SETUP_STATUS
  if [[ $SETUP_STATUS = "nonewinstall" ]]; then
    # We validated the directory exists, but now we need to verify the config file exists
    if [[ ! -f "$ATH_DIR/config.json" ]]; then
      # If the config file does not exist, we prompt to download one
      dialog --title "$DIALOG_TITLE" --yesno "No config file was found, would you like to download the default config file?" 8 60
      if [ $? -eq 0 ]; then
        RetrieveDefaultConfig
      else
        echo "Error: Config file not found, aborting"
        exit 1
      fi
    fi
  fi
}

# Takes a number argument and returns a letter starting at 0 = A, 1 = B, 2 = C, etc to 25 = Z
function NumberToLetter() {
  local __resultvar=$2
  local __number=$1
  local __letter=$(echo -n "$__number" | awk '{printf "%c", 65+$1}')
  eval $__resultvar="$__letter"
}

# Displays a dialog with information about a selected server, and a menu to connect to a
#   selected ssh_server or telnet_server
# Accepts a server name as an argument, and that is how they are indexed by jq going forward
function DisplayServerMenu() {
  local SERVER_NAME=$1
  local HEIGHT=20
  local WIDTH=80
  local CHOICE_HEIGHT=14
  local j
  local i
  declare -a SERVER_MENU_OPTIONS

  local SERVER_DESCRIPTION
  SERVER_DESCRIPTION=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .description" $ATH_DIR/config.json)
  local SERVER_WEBSITE
  SERVER_WEBSITE=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .website" $ATH_DIR/config.json)
  local SERVER_IRC
  SERVER_IRC=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .irc" $ATH_DIR/config.json)
  local SERVER_DISCORD
  SERVER_DISCORD=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .discord" $ATH_DIR/config.json)
  local SERVER_SSH_USERNAME
  SERVER_SSH_USERNAME=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_username" $ATH_DIR/config.json)
  local SERVER_SSH_PORT
  SERVER_SSH_PORT=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_port" $ATH_DIR/config.json)
  local SERVER_SSH_PASSWORD
  SERVER_SSH_PASSWORD=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_password" $ATH_DIR/config.json)
  local TELNET_SERVER_PORT
  TELNET_SERVER_PORT=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .telnet_port" $ATH_DIR/config.json)

  SERVER_DESCRIPTION="$SERVER_DESCRIPTION\n"
  # If SERVER_WEBSITE is not empty, add it to the description
  if [[ ! -z $SERVER_WEBSITE ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nWebsite: $SERVER_WEBSITE"
  fi
  # If SERVER_IRC is not empty, add it to the description
  if [[ ! -z $SERVER_IRC ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nIRC: $SERVER_IRC"
  fi
  # If SERVER_DISCORD is not empty, add it to the description
  if [[ ! -z $SERVER_DISCORD ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nDiscord: $SERVER_DISCORD"
  fi


  # Build SERVER_MENU_OPTIONS array with ssh servers first
  i=0 #Index counter for adding to array
  j=0 #Option menu value generator
  while IFS= read -r line # Read a line
  do
    local letter
    NumberToLetter $j letter
    SERVER_MENU_OPTIONS[ $i ]=$letter
    (( j++ ))
    # If SERVER_SSH_PASSWORD is not empty, add it to the description
    if [[ ! -z $SERVER_SSH_PASSWORD ]]; then
      SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nSSH Password: $SERVER_SSH_PASSWORD"
    fi
      SERVER_MENU_OPTIONS[ ($i + 1) ]="ssh $SERVER_SSH_USERNAME@$line"
    (( i++ ))
    (( i=(i+2) ))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_servers | .[]" < "$ATH_DIR/config.json")

  # Add telnet servers to list of options
  while IFS= read -r line # Read a line
  do
    local letter
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[ $i ]=$letter
    (( j++ ))
    SERVER_MENU_OPTIONS[ ($i + 1) ]="telnet $line"
    (( i=(i+2) ))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .telnet_servers | .[]" < "$ATH_DIR/config.json")

  # Add web clients to the list of options
  while IFS= read -r line # Read a line
  do
    local letter
    NumberToLetter $j letter
    SERVER_MENU_OPTIONS[ $i ]=$letter
    (( j++ ))
    SERVER_MENU_OPTIONS[ ($i + 1) ]="web-client $line"
    (( i=(i+2) ))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .web_clients | .[]" < "$ATH_DIR/config.json")

  # Add server IRC and Discord to the list of options
  local letter
  # If SERVER_IRC is not empty, add it to the menu
  if [[ -n $SERVER_IRC ]]; then
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[ $i ]=$letter
    (( j++ ))
    SERVER_MENU_OPTIONS[ ($i + 1) ]="irc $SERVER_IRC"
    (( i=(i+2) ))
  fi


  # If SERVER_DISCORD is not empty, add it to the menu
  if [[ -n $SERVER_DISCORD ]]; then
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[ $i ]=$letter
    (( j++ ))
    SERVER_MENU_OPTIONS[ ($i + 1) ]="discord $SERVER_DISCORD"
    (( i=(i+2) ))
  fi


  # loop over SERVER_MENU_OPTIONS and display them
  for i in "${SERVER_MENU_OPTIONS[@]}"
  do
    echo "$i"
  done

  exec 3>&1
  local SERVER_MENU_CHOICE
  SERVER_MENU_CHOICE=$(dialog \
    --backtitle "System Information" \
    --title "$SERVER_NAME" \
    --clear \
    --cancel-label "Back" \
    --menu "$SERVER_DESCRIPTION" $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${SERVER_MENU_OPTIONS[@]}" \
    2>&1 1>&3)
  exitStatus=$?
  exec 3>&-
  clear

  for i in "${!SERVER_MENU_OPTIONS[@]}"; do
    if [[ "${SERVER_MENU_OPTIONS[$i]}" = "${SERVER_MENU_CHOICE}" ]]; then
      local SERVER_SELECTION="${SERVER_MENU_OPTIONS[$i+1]}"
      local SSH_SERVER_NAME
      local TELNET_SERVER_NAME
      local WEB_CLIENT_URL
      # If server selection contains "ssh", then it is an ssh server
      if [[ "$SERVER_SELECTION" = *"ssh"* ]]; then
        # Remove "ssh" from the selection
        SSH_SERVER_NAME="${SERVER_SELECTION#*ssh }"
        ssh -t "$SSH_SERVER_NAME" -p"$SERVER_SSH_PORT" 2>&1
        DisplayServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "telnet", then it is a telnet server
      elif [[ "$SERVER_SELECTION" = *"telnet"* ]]; then
        # Remove "telnet" from the selection
        TELNET_SERVER_NAME="${SERVER_SELECTION#*telnet }"
        telnet "$TELNET_SERVER_NAME" "$TELNET_SERVER_PORT" 2>&1
        DisplayServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "web-client", then it is a web client
      elif [[ "$SERVER_SELECTION" = *"web-client"* ]]; then
        # Remove "web-client" from the selection
        WEB_CLIENT_URL="${SERVER_SELECTION#*web-client }"
        $URL_OPENER "$WEB_CLIENT_URL" 2>&1
        DisplayServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "irc", then it is an IRC server
      elif [[ "$SERVER_SELECTION" = *"irc"* ]]; then
        # Remove "irc" from the selection
        local IRC_SERVER_NAME="${SERVER_SELECTION#*irc }"
        $URL_OPENER "irc://$IRC_SERVER_NAME" 2>&1
        DisplayServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "discord", then it is a Discord server
      elif [[ "$SERVER_SELECTION" = *"discord"* ]]; then
        # Remove "discord" from the selection
        local DISCORD_SERVER_URL="${SERVER_SELECTION#*discord }"
        $URL_OPENER "$DISCORD_SERVER_URL" 2>&1
        DisplayServerMenu "$SERVER_NAME"
        exitStatus=$?
      fi

    fi
  done

  return $exitStatus
}

function DisplayRemotePlayMenu() {
  local HEIGHT=17
  local WIDTH=40
  local CHOICE_HEIGHT=10
  local j
  local i
  declare -a REMOTE_PLAY_OPTIONS

  i=0 #Index counter for adding to array
  j=0 #Option menu value generator
  while IFS= read -r line # Read a line
  do
    local letter
    NumberToLetter $j letter
    REMOTE_PLAY_OPTIONS[ $i ]=$letter
    (( j++ ))
    REMOTE_PLAY_OPTIONS[ ($i + 1) ]=$line
    (( i=(i+2) ))
  done < <(jq -r '.servers.nethack[].name' < "$ATH_DIR/config.json")

  exec 3>&1;
  local REMOTE_PLAY_CHOICE
  REMOTE_PLAY_CHOICE=$(dialog --clear \
                  --backtitle "$DIALOG_TITLE" \
                  --title "$TITLE" \
                  --cancel-label "Back" \
                  --menu "Public Nethack Servers" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${REMOTE_PLAY_OPTIONS[@]}" \
                  2>&1 1>&3)
  local exitStatus=$?
  exec 3>&-;
  clear

  for i in "${!REMOTE_PLAY_OPTIONS[@]}"; do
    if [[ "${REMOTE_PLAY_OPTIONS[$i]}" = "${REMOTE_PLAY_CHOICE}" ]]; then
      local SERVER_NAME="${REMOTE_PLAY_OPTIONS[$i+1]}"
      DisplayServerMenu "$SERVER_NAME"
      local res=$?
      if [ "$res" -eq 1 ]; then
        DisplayRemotePlayMenu
        exitStatus=$?
      fi
    fi
  done

  return $exitStatus
}

function DisplayMainMenu(){
  local HEIGHT=10
  local WIDTH=40
  local CHOICE_HEIGHT=4

  MAIN_MENU_OPTIONS=(
    A "Remote Play"
    B "Manage Installs"
    Q "Quit"
  )

  MAIN_MENU_CHOICE=$(dialog --clear \
                  --backtitle "$DIALOG_TITLE" \
                  --title "$TITLE" \
                  --cancel-label "Quit" \
                  --menu "Main Menu" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${MAIN_MENU_OPTIONS[@]}" \
                  2>&1 >/dev/tty)
  clear
  case $MAIN_MENU_CHOICE in
          A)
              DisplayRemotePlayMenu
              local res=$?
              if [ "$res" -eq 1 ]; then
                unset MAIN_MENU_CHOICE
                DisplayMainMenu
              fi
              ;;
          B)
              echo "You chose Option 2"
              ;;
          Q)
              exit 0
              ;;
  esac
}


###########
# Runtime #
###########

# Parse the CLI for a directory flag
ParseCommandLineOptions "$@"
# Check our OS type
CheckOSType
# Set up our Package manager vars
SetupPackageManager
# Set up our list of missing dependencies, if there are any
SetupDependencyList
# Install the dependencies if necessary
InstallDependencies
# Set up our installation if necessary
SetupInstallation
DisplayMainMenu