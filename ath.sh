#!/bin/bash

# Global Vars
DIALOG_TITLE="All The Hacks"
ATH_DIR="$HOME/allthehacks/"
DEFAULT_CONFIG_URL="https://raw.githubusercontent.com/yamamushi/all-the-hacks/master/config.json"
PACKAGE_MANAGER='unknown'
PLATFORM='unknown'
MISSING_DEPENDENCIES=""

# Parse command line options
# -c <config file> (default is $HOME/allthehacks/config.json)
# -d <directory> (default is $HOME/allthehacks/)
# -h <help>
function ParseCommandLineOptions() {
  local OPTION
  while getopts "c:d:h" OPTION; do
      case $OPTION in
          c)
              ATH_CONFIG_FILE=$OPTARG
              ;;
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
        if [ $OS == 'Ubuntu' ]; then
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
}

# Check to see if all the dependencies are installed, and if not, prompt to install
function InstallDependencies() {
  # If MISSING_DEPENDENCIES is not empty, we need to install the missing dependencies
  if [[ ! -z $MISSING_DEPENDENCIES ]]; then
    echo "Missing Dependencies: $MISSING_DEPENDENCIES"
    echo "Would you like to install them now? (y/n)"
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if [[ $PACKAGE_MANAGER == 'apt-get' ]]; then
        # If package installation fails we exit with a message to the user
        sudo apt-get install $MISSING_DEPENDENCIES || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'apt' ]]; then
        sudo apt install $MISSING_DEPENDENCIES || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'yum' ]]; then
        sudo yum install $MISSING_DEPENDENCIES || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
      elif [[ $PACKAGE_MANAGER == 'brew' ]]; then
        brew install $MISSING_DEPENDENCIES || { echo "Error: Unable to install dependencies. Please check the above errors and try again."; exit 1; }
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
  local __letter=$(echo -n $__number | awk '{printf "%c", 65+$1}')
  eval $__resultvar="$__letter"
}

# Takes a letter argument and converts to a number starting at A = 0, B = 1, C = 2, etc to Z = 25
function LetterToNumber() {
  local __resultvar=$2
  local __letter=$1
  local __number=$(printf '%d\n' "'$__letter")
  eval $__resultvar="$__number"
}

function RemotePlay() {
  local HEIGHT=17
  local WIDTH=40
  local CHOICE_HEIGHT=10


  # For every line from jq on the remote play list output .servers.nethack[].name, add it to the array indexed by an ascending letter
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
  REMOTE_PLAY_CHOICE=$(dialog --clear \
                  --backtitle "$DIALOG_TITLE" \
                  --title "$TITLE" \
                  --menu "Public Nethack Servers" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${REMOTE_PLAY_OPTIONS[@]}" \
                  2>&1 1>&3)
  local exitStatus=$?
  exec 3>&-;

  clear

  j=0 # We already defined this above
  for i in "${!REMOTE_PLAY_OPTIONS[@]}"; do
    if [[ "${REMOTE_PLAY_OPTIONS[$i]}" = "${REMOTE_PLAY_CHOICE}" ]]; then
      #echo "${REMOTE_PLAY_OPTIONS[$i+1]}"
      description=$(jq -r ".servers.nethack[] | select(.name==\"${REMOTE_PLAY_OPTIONS[$i+1]}\") | .description" ~/allthehacks/config.json)
      echo $description
    fi
    (( j++ ))
  done

  return $exitStatus
}

function MainMenu(){
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
                  --menu "Main Menu" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${MAIN_MENU_OPTIONS[@]}" \
                  2>&1 >/dev/tty)

  clear
  case $MAIN_MENU_CHOICE in
          A)
              RemotePlay
              local res=$?
              if [ "$res" -eq 1 ]; then
                unset MAIN_MENU_CHOICE
                MainMenu
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
MainMenu