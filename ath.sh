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
        sudo apt-get install "$MISSING_DEPENDENCIES" || {
          echo "Error: Unable to install dependencies. Please check the above errors and try again."
          exit 1
        }
      elif [[ $PACKAGE_MANAGER == 'apt' ]]; then
        sudo apt install "$MISSING_DEPENDENCIES" || {
          echo "Error: Unable to install dependencies. Please check the above errors and try again."
          exit 1
        }
      elif [[ $PACKAGE_MANAGER == 'yum' ]]; then
        sudo yum install "$MISSING_DEPENDENCIES" || {
          echo "Error: Unable to install dependencies. Please check the above errors and try again."
          exit 1
        }
      elif [[ $PACKAGE_MANAGER == 'brew' ]]; then
        brew install "$MISSING_DEPENDENCIES" || {
          echo "Error: Unable to install dependencies. Please check the above errors and try again."
          exit 1
        }
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
    curl -s -o "$ATH_DIR/config.json" "$DEFAULT_CONFIG_URL" || {
      echo "Error: Unable to download config file. Please check your internet connection and try again."
      exit 1
    }
  fi
}

function CheckForAthDir() {
  local __resultvar=$1
  # Check to see if .allthehacks directory is present, and if not, prompt whether to create it
  if [ ! -d "$ATH_DIR" ]; then

    # Ask user if they want to create the directory
    dialog --backtitle "$DIALOG_TITLE" --title "New Install" --yesno "An installation was not found, would you like to create the $ATH_DIR directory and download the default configs?" 8 60
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

# Set up our installation directory and configuration if they don't exist
function SetupInstallation() {
  local SETUP_STATUS
  CheckForAthDir SETUP_STATUS
  if [[ $SETUP_STATUS = "nonewinstall" ]]; then
    # We validated the directory exists, but now we need to verify the config file exists
    if [[ ! -f "$ATH_DIR/config.json" ]]; then
      # If the config file does not exist, we prompt to download one
      dialog --backtitle "$DIALOG_TITLE" --title "No Config Found" --yesno "No config file was found, would you like to download the default config file?" 8 60
      if [ $? -eq 0 ]; then
        RetrieveDefaultConfig
      else
        echo "Error: Config file not found, aborting"
        exit 1
      fi
    fi
  fi
}

# Validates whether the config.json is valid JSON
function ValidateConfig() {
  # Check to see if the config file is valid JSON
  if ! [ "$(jq -e '.' "$ATH_DIR/config.json")" ]; then
    # If the config file is not valid JSON, we need to exit with an error
    echo "Error: Config file is not valid JSON, aborting"
    exit 1
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
function DisplayNethackServerMenu() {
  local SERVER_NAME=$1
  local HEIGHT=24
  local WIDTH=80
  local CHOICE_HEIGHT=18
  local j
  local i
  declare -a SERVER_MENU_OPTIONS

  local SERVER_DESCRIPTION
  SERVER_DESCRIPTION=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .description" "$ATH_DIR"/config.json)
  local SERVER_WEBSITE
  SERVER_WEBSITE=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .website" "$ATH_DIR"/config.json)
  local SERVER_IRC
  SERVER_IRC=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .irc" "$ATH_DIR"/config.json)
  local SERVER_DISCORD
  SERVER_DISCORD=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .discord" "$ATH_DIR"/config.json)
  local SERVER_SSH_USERNAME
  SERVER_SSH_USERNAME=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_username" "$ATH_DIR"/config.json)
  local SERVER_SSH_PORT
  SERVER_SSH_PORT=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_port" "$ATH_DIR"/config.json)
  local SERVER_SSH_PASSWORD
  SERVER_SSH_PASSWORD=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_password" "$ATH_DIR"/config.json)
  local TELNET_SERVER_PORT
  TELNET_SERVER_PORT=$(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .telnet_port" "$ATH_DIR"/config.json)

  SERVER_DESCRIPTION="$SERVER_DESCRIPTION\n"
  # If SERVER_WEBSITE is not empty, add it to the description
  if [[ -n $SERVER_WEBSITE ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nWebsite: $SERVER_WEBSITE"
  fi
  # If SERVER_IRC is not empty, add it to the description
  if [[ -n $SERVER_IRC ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nIRC: $SERVER_IRC"
  fi
  # If SERVER_DISCORD is not empty, add it to the description
  if [[ -n $SERVER_DISCORD ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nDiscord: $SERVER_DISCORD"
  fi

  # Get locations and append them to the description
  local SERVER_LOCATIONS
  while IFS= read -r line; do # Read a line
    # If line is not empty, add it to the description
    if [[ -n $line ]]; then
      # If SERVER_LOCATIONS is empty, add the first location to it
      if [[ -z $SERVER_LOCATIONS ]]; then
        SERVER_LOCATIONS="$line"
      else
        SERVER_LOCATIONS="$SERVER_LOCATIONS | $line"
      fi
    fi
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .locations | .[] " "$ATH_DIR"/config.json)

  # If SERVER_LOCATIONS is not empty, add it to the description
  if [[ -n $SERVER_LOCATIONS ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nLocations: $SERVER_LOCATIONS"
  fi

  # If SERVER_SSH_PASSWORD is not empty, add it to the description
  if [[ -n $SERVER_SSH_PASSWORD ]]; then
    SERVER_DESCRIPTION="$SERVER_DESCRIPTION\nSSH Password: $SERVER_SSH_PASSWORD"
  fi

  # Build SERVER_MENU_OPTIONS array with ssh servers first
  i=0                         #Index counter for adding to array
  j=0                         #Option menu value generator
  while IFS= read -r line; do # Read a line
    local letter
    NumberToLetter $j letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="ssh $SERVER_SSH_USERNAME@$line"
    ((i = (i + 2)))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .ssh_servers | .[]" <"$ATH_DIR"/config.json)

  # Add telnet servers to list of options
  while IFS= read -r line; do # Read a line
    local letter
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="telnet $line"
    ((i = (i + 2)))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .telnet_servers | .[]" <"$ATH_DIR"/config.json)

  # Add web clients to the list of options
  while IFS= read -r line; do # Read a line
    local letter
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="web-client $line"
    ((i = (i + 2)))
  done < <(jq -r ".servers.nethack[] | select(.name==\"${SERVER_NAME}\") | .web_clients | .[]" <"$ATH_DIR"/config.json)

  # Add server IRC and Discord to the list of options
  local letter
  # If SERVER_WEBSITE is not empty, add it to the menu
  if [[ -n $SERVER_WEBSITE ]]; then
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="website $SERVER_WEBSITE"
    ((i = (i + 2)))
  fi
  # If SERVER_IRC is not empty, add it to the menu
  if [[ -n $SERVER_IRC ]]; then
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="irc $SERVER_IRC"
    ((i = (i + 2)))
  fi
  # If SERVER_DISCORD is not empty, add it to the menu
  if [[ -n $SERVER_DISCORD ]]; then
    NumberToLetter "$j" letter
    SERVER_MENU_OPTIONS[$i]=$letter
    ((j++))
    SERVER_MENU_OPTIONS[($i + 1)]="discord $SERVER_DISCORD"
    ((i = (i + 2)))
  fi

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
      local SERVER_SELECTION="${SERVER_MENU_OPTIONS[$i + 1]}"
      local SSH_SERVER_NAME
      local TELNET_SERVER_NAME
      local WEB_CLIENT_URL
      # If server selection contains "ssh", then it is an ssh server
      if [[ "$SERVER_SELECTION" = *"ssh"* ]]; then
        # Remove "ssh" from the selection
        SSH_SERVER_NAME="${SERVER_SELECTION#*ssh }"
        ssh -t "$SSH_SERVER_NAME" -p"$SERVER_SSH_PORT" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "telnet", then it is a telnet server
      elif [[ "$SERVER_SELECTION" = *"telnet"* ]]; then
        # Remove "telnet" from the selection
        TELNET_SERVER_NAME="${SERVER_SELECTION#*telnet }"
        telnet "$TELNET_SERVER_NAME" "$TELNET_SERVER_PORT" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "web-client", then it is a web client
      elif [[ "$SERVER_SELECTION" = *"web-client"* ]]; then
        # Remove "web-client" from the selection
        WEB_CLIENT_URL="${SERVER_SELECTION#*web-client }"
        $URL_OPENER "$WEB_CLIENT_URL" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "irc", then it is an IRC server
      elif [[ "$SERVER_SELECTION" = *"irc"* ]]; then
        # Remove "irc" from the selection
        local IRC_SERVER_NAME="${SERVER_SELECTION#*irc }"
        $URL_OPENER "irc://$IRC_SERVER_NAME" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "discord", then it is a Discord server
      elif [[ "$SERVER_SELECTION" = *"discord"* ]]; then
        # Remove "discord" from the selection
        local DISCORD_SERVER_URL="${SERVER_SELECTION#*discord }"
        $URL_OPENER "$DISCORD_SERVER_URL" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      # If server selection contains "website", then it is a website
      elif [[ "$SERVER_SELECTION" = *"website"* ]]; then
        # Remove "website" from the selection
        local WEBSITE_URL="${SERVER_SELECTION#*website }"
        $URL_OPENER "$WEBSITE_URL" 2>&1
        DisplayNethackServerMenu "$SERVER_NAME"
        exitStatus=$?
      fi

    fi
  done

  return $exitStatus
}

# Displays a dialog with a list of all servers from the config file
function DisplayNethackRemotePlayMenu() {
  local HEIGHT=18
  local WIDTH=40
  local CHOICE_HEIGHT=10
  local j
  local i
  declare -a REMOTE_PLAY_OPTIONS

  i=0                         #Index counter for adding to array
  j=0                         #Option menu value generator
  while IFS= read -r line; do # Read a line
    local letter
    NumberToLetter $j letter
    REMOTE_PLAY_OPTIONS[$i]=$letter
    ((j++))
    REMOTE_PLAY_OPTIONS[($i + 1)]=$line
    ((i = (i + 2)))
  done < <(jq -r '.servers.nethack[].name' <"$ATH_DIR/config.json")

  exec 3>&1
  local REMOTE_PLAY_CHOICE
  REMOTE_PLAY_CHOICE=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "Public Nethack Servers" \
    --cancel-label "Back" \
    --menu "Choose a server to connect to" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${REMOTE_PLAY_OPTIONS[@]}" \
    2>&1 1>&3)
  local exitStatus=$?
  exec 3>&-
  clear

  for i in "${!REMOTE_PLAY_OPTIONS[@]}"; do
    if [[ "${REMOTE_PLAY_OPTIONS[$i]}" = "${REMOTE_PLAY_CHOICE}" ]]; then
      local SERVER_NAME="${REMOTE_PLAY_OPTIONS[$i + 1]}"
      DisplayNethackServerMenu "$SERVER_NAME"
      local res=$?
      if [ "$res" -eq 1 ]; then
        DisplayNethackRemotePlayMenu
        exitStatus=$?
      fi
    fi
  done

  return $exitStatus
}

# Escapes the name of the game into a shell-friendly format, used by anything that is writing
function EscapedGameName() {
  local GAME_NAME=$1
  # Change to the build directory and run the build steps
  local ESCAPED_GAME_NAME
  # Replace spaces with dashes in the game name
  ESCAPED_GAME_NAME="${GAME_NAME// /-}"
  # Replaces ' with '-' in the game name
  ESCAPED_GAME_NAME="${ESCAPED_GAME_NAME//\'/-}"

  echo "$ESCAPED_GAME_NAME"
}

# Installs the provided game name into the games directory
function InstallGame(){
  local GAME_NAME=$1

  local GAME_INSTALL_COMMAND
  GAME_INSTALL_COMMAND=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .install_command_$PLATFORM" <"$ATH_DIR"/config.json)

  local ESCAPED_GAME_NAME
  ESCAPED_GAME_NAME=$(EscapedGameName "$GAME_NAME")


  local GAME_INSTALL_PATH
  GAME_INSTALL_PATH="$ATH_DIR/games/$ESCAPED_GAME_NAME"

  # Replace the word "ATH_INSTALL_PATH_VAR" with the GAME_INSTALL_PATH variable
  GAME_INSTALL_COMMAND="${GAME_INSTALL_COMMAND//ATH_INSTALL_PATH_VAR/$GAME_INSTALL_PATH}"

  local USER_NAME
  USER_NAME=$(whoami)

  # Replace the word "ATH_USER_NAME_VAR" with the USER_NAME variable
  GAME_INSTALL_COMMAND="${GAME_INSTALL_COMMAND//ATH_USER_NAME_VAR/$USER_NAME}"

  echo "Game installation command:"
  echo "$GAME_INSTALL_COMMAND"

  # Run the game installation command
  eval "$GAME_INSTALL_COMMAND"
  if [ $? -ne 0 ]; then
    echo "Game installation failed."
    return 1
  fi
  return 0
}

# Builds the game, but does not install it
function BuildGame() {
  local GAME_NAME=$1
  # Get a list of all of the build steps for this game
  declare -a BUILD_STEPS
  while IFS= read -r line # Read a line
  do
    # append the line to the array PATCH_LIST
    BUILD_STEPS+=("$line")
  # We pass || true here to ignore errors from the read if the field doesn't exist
  done < <(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .build_steps_$PLATFORM | .[]" <"$ATH_DIR"/config.json || true)

  # Tell the user what the build steps are
  printf "\n"
  echo "The following build steps will be performed:"
  for i in "${!BUILD_STEPS[@]}"; do
    echo "${BUILD_STEPS[$i]}"
  done
  printf "\n"

  echo "Are you sure you want to continue? (y/n)"
  read -r answer
  if [[ "$answer" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Change to the build directory and run the build steps
    local ESCAPED_GAME_NAME
    ESCAPED_GAME_NAME=$(EscapedGameName "$GAME_NAME")
    local LOCAL_REPO_PATH="$ATH_DIR/repos/$ESCAPED_GAME_NAME"
    cd "$LOCAL_REPO_PATH" || exit

    # Run the build steps
    for i in "${!BUILD_STEPS[@]}"; do
      printf "\n"
      echo "Running build step: ${BUILD_STEPS[$i]}"
      eval "${BUILD_STEPS[$i]}"
      # If the build step fails, exit 1
      if [ $? -ne 0 ]; then
        # using printf two new lines to make the error message look nice
        printf "\n\n"
        echo "Build step failed: ${BUILD_STEPS[$i]}"
        exit 1
      fi
    done
  else
    echo "Build aborted, exiting."
    exit 1
  fi


  return 0 # Return 0 if build was successful
}

# Lists all of the patches for a given game name, and installs them after prompting the user to continue or not
function SetupGamePatches() {
  local GAME_NAME=$1
  # Get list of patches to apply from the config file using read line
  declare -a PATCH_LIST
  while IFS= read -r line # Read a line
  do
    # append the line to the array PATCH_LIST
    PATCH_LIST+=("$line")
  done < <(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .patch_names_$PLATFORM | .[]" <"$ATH_DIR"/config.json || true)

  # If there are patches to apply, and the first entry is not null tell the user and download them
  if (( ${#PATCH_LIST[@]} )); then
    echo "Found ${#PATCH_LIST[@]} patches to apply for this platform ($PLATFORM):"
    # Print the list of patches to apply
    for i in "${!PATCH_LIST[@]}"; do
      echo "${PATCH_LIST[$i]}"
    done
    printf "\n"

    echo "Downloading patches from GitHub (https://github.com/yamamushi/all-the-hacks/tree/master/patches/$PLATFORM/)"
    echo "Press ctrl-c now to cancel"
    # Print dots while waiting for the user to ctrl-c for 5 seconds
    for i in {1..5}; do
      echo -n "."
      sleep 1
    done

    # Change to the build directory and run the build steps
    local ESCAPED_GAME_NAME
    ESCAPED_GAME_NAME=$(EscapedGameName "$GAME_NAME")
    local LOCAL_REPO_PATH="$ATH_DIR/repos/$ESCAPED_GAME_NAME"
    cd "$LOCAL_REPO_PATH" || exit

    # Check to see if patch directory exists, if not create it
    if [ ! -d "$ATH_DIR/patches/$PLATFORM" ]; then
      mkdir -p "$ATH_DIR/patches/$PLATFORM"
    fi
    local PATCH_DOWNLOAD_PATH="$ATH_DIR/patches/$PLATFORM"
    local PATCH_URL_BASE="https://raw.githubusercontent.com/yamamushi/all-the-hacks/master/patches/$PLATFORM/"

    for i in "${!PATCH_LIST[@]}"; do
      local PATCH_NAME="${PATCH_LIST[$i]}"
      local PATCH_URL="$PATCH_URL_BASE/$PATCH_NAME"
      local PATCH_PATH="$PATCH_DOWNLOAD_PATH/$PATCH_NAME"

      printf "\n"
      echo "Downloading $PATCH_URL to $PATCH_DOWNLOAD_PATH"
      curl -L "$PATCH_URL" -o "$PATCH_PATH"
      if [ $? -eq 1 ]; then
        # Something went wrong, abort
        echo "Error downloading patch, aborting"
        exit 1
      fi

      printf "\n"
      echo "Applying $PATCH_NAME"
      git apply "$PATCH_PATH"
    done
    printf "\n"
  fi
  return 0 # Success
}

# Cleans the git repo for a provided game name
function CleanRepo(){
  GAME_NAME=$1

  local ESCAPED_GAME_NAME
  ESCAPED_GAME_NAME=$(EscapedGameName "$GAME_NAME")
  local LOCAL_REPO_PATH="$ATH_DIR/repos/$ESCAPED_GAME_NAME"

  echo "Cleaning repository"
  cd "$LOCAL_REPO_PATH" || exit
  git clean -fdx
  if [ $? -eq 1 ]; then
    # Something went wrong, abort
    echo "Error on 'git clean -fdx'"
    return 1 # Abort
  fi
  git checkout .
  if [ $? -eq 1 ]; then
    # Something went wrong, abort
    echo "Error checking out 'git checkout .'"
    return 1 # Abort
  fi
  return 0 # Success
}

# Takes a game name argument and clones it into the repos directory
function GitCloneGame() {
  local GAME_NAME=$1
  # Check for repos directory, if it doesn't exist, create it
  if [ ! -d "$ATH_DIR/repos" ]; then
    mkdir "$ATH_DIR/repos"
  fi

  local GAME_GIT_REPOSITORY
  GAME_GIT_REPOSITORY=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .git_repository" <"$ATH_DIR"/config.json)

  local ESCAPED_GAME_NAME
  ESCAPED_GAME_NAME=$(EscapedGameName "$GAME_NAME")
  local LOCAL_REPO_PATH="$ATH_DIR/repos/$ESCAPED_GAME_NAME"

  local DOWNLOAD_REPOSITORY=true
  # If the local repository directory exists, remove it so we can clone the repository again
  if [ -d "$LOCAL_REPO_PATH" ]; then
    echo "Found existing repository, removing and cloning again"
    # Prompt user to proceed with removing the existing repository or not
    dialog --backtitle "$DIALOG_TITLE" --title "$GAME_NAME" --yesno "An existing repository download was detected, do you want to delete it and re-download it?" 8 60
    if [ $? -eq 1 ]; then
      clear # Clear the screen
      DOWNLOAD_REPOSITORY=false
    else
      clear # Clear the screen
      echo "Removing existing repository at $LOCAL_REPO_PATH"
      rm -rf "$LOCAL_REPO_PATH"
    fi
  fi

  if [ "$DOWNLOAD_REPOSITORY" = "true" ]; then
    echo "Cloning $GAME_GIT_REPOSITORY into $LOCAL_REPO_PATH"
    # Clone the repository into the local repository directory
    git clone "$GAME_GIT_REPOSITORY" "$LOCAL_REPO_PATH"
    if [ $? -eq 1 ]; then
      # Something went wrong, abort
      echo "Error cloning repository"
      return 1
    fi

    # Checkout the correct branch
    local BRANCH=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .git_branch" <"$ATH_DIR"/config.json)
    echo "Checking out branch $BRANCH"

    cd "$LOCAL_REPO_PATH" || exit
    git checkout "$BRANCH"
    if [ $? -eq 1 ]; then
      # Something went wrong, abort
      echo "Error checking out branch"
      return 1 # Error
    fi

    # Checkout the correct commit
    local COMMIT=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .git_commit" <"$ATH_DIR"/config.json)
    # If commit is "latest", then skip this step
    if [ "$COMMIT" != "latest" ]; then
      echo "Checking out commit $COMMIT"
      git checkout "$COMMIT"
      if [ $? -eq 1 ]; then
        # Something went wrong, abort
        echo "Error checking out commit"
        return 1 # Abort
      fi
    fi
  else
    # Clean the repository, so we can patch and build it again
    CleanRepo "$GAME_NAME"
    if [ $? -eq 1 ]; then
      # Something went wrong, abort
      echo "CleanRepo error, aborting program."
      exit 1 # Abort
    fi
  fi
  return 0 # Success
}

# Displays an error message through dialog and returns 0 for success - always
function DisplayErrorMessage() {
  local MESSAGE=$1
  dialog --backtitle "$DIALOG_TITLE" --title "Error" --msgbox "$MESSAGE" 8 60
  return 0 # Success
}

# Manages all the installation steps for a game
function Installation() {
  local GAME_NAME=$1
  # Check to see if installed is true in the config file for this game
  local INSTALLED
  INSTALLED=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .installed" <"$ATH_DIR"/config.json)
  if [ "$INSTALLED" = "true" ]; then
    # Prompt user to proceed with reinstalling, remind them that no saved games will be lost
    dialog --backtitle "$DIALOG_TITLE" --title "$GAME_NAME" --yesno "An existing installation was detected in your configuration, would you like to proceed with reinstalling?\n\nNo saved game data will be overwritten by this action" 8 60
    if [ $? -eq 1 ]; then
      return 0 # User chose not to reinstall
    fi
  fi

  clear # Clear the screen and get ready for the installation

  echo "Installing $GAME_NAME, press ctrl-c now to cancel"
  # Print dots while waiting for the user to ctrl-c for 5 seconds
  for i in {1..5}; do
    echo -n "."
    sleep 1
  done

  echo "Proceeding with installation."
  GitCloneGame "$GAME_NAME"
  if [ $? -eq 1 ]; then
    Something went wrong, abort
    echo "Error setting up repository, aborting"
    exit 1
  fi

  printf "\n"
  echo "Checking for patches"
  SetupGamePatches "$GAME_NAME"
  if [ $? -eq 1 ]; then
    # Something went wrong, abort
    echo "Error checking for patches, aborting"
    exit 1
  fi

  echo "Preparing to build $GAME_NAME"
  BuildGame "$GAME_NAME"
  if [ $? -eq 1 ]; then
    Something went wrong, abort
    echo "Error building game, aborting"
    exit 1
  fi
  echo "$GAME_NAME was built successfully"
  printf "\n"

  echo "Finalizing installation"
  InstallGame "$GAME_NAME"
  if [ $? -eq 1 ]; then
    # Something went wrong, abort
    echo "Error installing game, aborting"
    exit 1
  fi
  printf "\n"

  # Sets the installed status to true for this game
  # shellcheck disable=SC2094
  cat <<<"$(jq -r "(.games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .installed) |= true" "$ATH_DIR"/config.json)" >"$ATH_DIR"/config.json

  echo "$GAME_NAME was installed successfully"
  printf "\n"
  # Print 5 dots to indicate that the installation is complete
  for i in {1..5}; do
    echo -n "."
    sleep 1
  done

  return 0 # Return 1 to indicate that the game was installed
}

# Displays the menu prompt before installation begins to confirm the user wants to install
function DisplayInstallGameConfirmationMenu() {
  local GAME_NAME=$1
  local HEIGHT=24
  local WIDTH=80
  local CHOICE_HEIGHT=18

  dialog --backtitle "$DIALOG_TITLE" --title "$GAME_NAME" --yesno "Would you like to configure the installation before proceeding?" 8 60
  if [ $? -eq 0 ]; then
    # Configure the installation
    echo "Configuration Unimplemented"
    sleep 5
  fi

  dialog --backtitle "$DIALOG_TITLE" --title "$GAME_NAME" --yesno "Proceed with installation of $GAME_NAME?" 8 60
  if [ $? -eq 0 ]; then
    # Configure the installation
    echo "Configuration Unimplemented"
  else
     return 0 # User chose not to install
  fi
  exec 3>&1
  Installation "$GAME_NAME"
  exitStatus=$?
  exec 3>&-
  if [ "$exitStatus" -eq 0 ]; then
    dialog --backtitle "$DIALOG_TITLE" --title "$GAME_NAME" --yesno "Installation of $GAME_NAME has been completed, would you like to set up exports for this game?" 8 60
    if [ $? -eq 0 ]; then
      # Configure the installation
      echo "Exports Unimplemented"
      sleep 5
    fi
    return 0
  else
    echo "Installation of $GAME_NAME failed, please report the above errors."
    exit 1
  fi
  return 0 # Success
}

# Displays a list of information about the game, including installation, updating, etc.
function DisplayInstallGameInformationMenu() {
  local GAME_NAME="$1"
  local HEIGHT=24
  local WIDTH=80
  local CHOICE_HEIGHT=18

  local MANAGE_GAME_MENU_TEXT

  local GAME_DESCRIPTION
  GAME_DESCRIPTION=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .description" "$ATH_DIR"/config.json)
  # If GAME_DESCRIPTION is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_DESCRIPTION" ]; then
    MANAGE_GAME_MENU_TEXT="$GAME_DESCRIPTION\n"
  fi

  local GAME_VARIANT_TYPE
  GAME_VARIANT_TYPE=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .variant_type" "$ATH_DIR"/config.json)
  # If GAME_VARIANT_TYPE is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_VARIANT_TYPE" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nVariant Type: $GAME_VARIANT_TYPE"
  fi

  local GAME_DEVELOPMENT_STATUS
  GAME_DEVELOPMENT_STATUS=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .development_status" "$ATH_DIR"/config.json)
  # If GAME_DEVELOPMENT_STATUS is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_DEVELOPMENT_STATUS" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nStatus: $GAME_DEVELOPMENT_STATUS\n"
  fi

  local GAME_WEBSITE
  GAME_WEBSITE=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .website" "$ATH_DIR"/config.json)
  # If GAME_WEBSITE is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_WEBSITE" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nWebsite: $GAME_WEBSITE"
  fi

  local GAME_WIKI_ENTRY
  GAME_WIKI_ENTRY=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .nethack_wiki_entry" "$ATH_DIR"/config.json)
  # If GAME_WIKI_ENTRY is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_WIKI_ENTRY" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nWiki Entry: $GAME_WIKI_ENTRY"
  fi

  local GAME_GITHUB_PAGE
  GAME_GITHUB_PAGE=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .github_page" "$ATH_DIR"/config.json)
  # If GAME_GITHUB_PAGE is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_GITHUB_PAGE" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nGithub Page: $GAME_GITHUB_PAGE"
  fi

  local GAME_MAINTAINER
  GAME_MAINTAINER=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .maintainer" "$ATH_DIR"/config.json)
  # If GAME_MAINTAINER is not blank, then add it to MANAGE_GAME_MENU_TEXT
  if [ -n "$GAME_MAINTAINER" ]; then
    MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nMaintainer: $GAME_MAINTAINER"

    local GAME_MAINTAINER_URL
    GAME_MAINTAINER_URL=$(jq -r ".games.nethack_variants[] | select(.name==\"${GAME_NAME}\") | .maintainer_url" "$ATH_DIR"/config.json)
    # If GAME_MAINTAINER_URL is not blank, then add it to MANAGE_GAME_MENU_TEXT
    if [ -n "$GAME_MAINTAINER_URL" ]; then
      MANAGE_GAME_MENU_TEXT="$MANAGE_GAME_MENU_TEXT\nMaintainer's Site: $GAME_MAINTAINER_URL"
    fi
  fi

  local MANAGE_GAME_MENU_OPTIONS
  MANAGE_GAME_MENU_OPTIONS=(
    A "Install ${GAME_NAME}"
    B "Update ${GAME_NAME}"
    C "Remove ${GAME_NAME}"
    D "Setup Exports for ${GAME_NAME}"
  )

  local j
  j=4
  local i
  i=8

  # If GAME_WEBSITE is not blank, then add it to MANAGE_GAME_MENU_OPTIONS
  if [ -n "$GAME_WEBSITE" ]; then
    local WEBSITE_MENU_OPTION
    NumberToLetter "$j" WEBSITE_MENU_OPTION
    ((j++))
    MANAGE_GAME_MENU_OPTIONS[$i]="$WEBSITE_MENU_OPTION"
    MANAGE_GAME_MENU_OPTIONS[$i + 1]="website $GAME_WEBSITE"
    ((i = (i + 2)))
  fi

  # If GAME_WIKI_ENTRY is not blank, then add it to MANAGE_GAME_MENU_OPTIONS
  if [ -n "$GAME_WIKI_ENTRY" ]; then
    local WIKI_ENTRY_MENU_OPTION
    NumberToLetter "$j" WIKI_ENTRY_MENU_OPTION
    ((j++))
    MANAGE_GAME_MENU_OPTIONS[$i]="$WIKI_ENTRY_MENU_OPTION"
    MANAGE_GAME_MENU_OPTIONS[$i + 1]="wiki $GAME_WIKI_ENTRY"
    ((i = (i + 2)))
  fi

  # If GAME_GITHUB_PAGE is not blank, then add it to MANAGE_GAME_MENU_OPTIONS
  if [ -n "$GAME_GITHUB_PAGE" ]; then
    local GITHUB_PAGE_MENU_OPTION
    NumberToLetter "$j" GITHUB_PAGE_MENU_OPTION
    ((j++))
    MANAGE_GAME_MENU_OPTIONS[$i]="$GITHUB_PAGE_MENU_OPTION"
    MANAGE_GAME_MENU_OPTIONS[$i + 1]="github $GAME_GITHUB_PAGE"
    ((i = (i + 2)))
  fi

  # If GAME_MAINTAINER_URL is not blank, then add it to MANAGE_GAME_MENU_OPTIONS
  if [ -n "$GAME_MAINTAINER_URL" ]; then
    local MAINTAINER_URL_MENU_OPTION
    NumberToLetter "$j" MAINTAINER_URL_MENU_OPTION
    ((j++))
    MANAGE_GAME_MENU_OPTIONS[$i]="$MAINTAINER_URL_MENU_OPTION"
    MANAGE_GAME_MENU_OPTIONS[$i + 1]="maintainer $GAME_MAINTAINER_URL"
    ((i = (i + 2)))
  fi

  exec 3>&1
  local MANAGE_GAME_MENU_CHOICE
  MANAGE_GAME_MENU_CHOICE=$(dialog \
    --backtitle "$DIALOG_TITLE" \
    --title "Manage $GAME_NAME" \
    --clear \
    --cancel-label "Back" \
    --menu "$MANAGE_GAME_MENU_TEXT" $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${MANAGE_GAME_MENU_OPTIONS[@]}" \
    2>&1 1>&3)
  exitStatus=$?
  exec 3>&-
  clear

  # Parse selected option
  for i in "${!MANAGE_GAME_MENU_OPTIONS[@]}"; do
    if [[ "${MANAGE_GAME_MENU_OPTIONS[$i]}" = "${MANAGE_GAME_MENU_CHOICE}" ]]; then
      local OPTION_SELECTION="${MANAGE_GAME_MENU_OPTIONS[$i + 1]}"
      # If option selection begins with "website", then it is the website option
      if [[ "$OPTION_SELECTION" = "website"* ]]; then
        # Remove "website" from the selection
        local WEBSITE_URL
        WEBSITE_URL="${OPTION_SELECTION#*website }"
        $URL_OPENER "$WEBSITE_URL"
        DisplayInstallGameInformationMenu "$GAME_NAME"
        exitStatus=$?
      # If option selection begins with "wiki", then it is the wiki entry option
      elif [[ "$OPTION_SELECTION" = "wiki"* ]]; then
        # Remove "wiki" from the selection
        local WIKI_URL
        WIKI_URL="${OPTION_SELECTION#*wiki }"
        $URL_OPENER "$WIKI_URL"
        DisplayInstallGameInformationMenu "$GAME_NAME"
        exitStatus=$?
      # If option selection begins with "maintainer", then it is the maintainer option
      elif [[ "$OPTION_SELECTION" = "maintainer"* ]]; then
        # Remove "maintainer" from the selection
        local MAINTAINER_URL
        MAINTAINER_URL="${OPTION_SELECTION#*maintainer }"
        $URL_OPENER "$MAINTAINER_URL"
        DisplayInstallGameInformationMenu "$GAME_NAME"
        exitStatus=$?
      # If option selection begins with "github", then it is the github option
      elif [[ "$OPTION_SELECTION" = "github"* ]]; then
        local GITHUB_URL
        # Remove "github" from the selection
        GITHUB_URL="${OPTION_SELECTION#*github }"
        $URL_OPENER "$GITHUB_URL"
        DisplayInstallGameInformationMenu "$GAME_NAME"
        exitStatus=$?
      # If option selection begins with "install", then it is the install option
      elif [[ "$OPTION_SELECTION" = "Install"* ]]; then
        # Check to see if an installation method is available for our platform
        local VALID_INSTALL_PLATFORM
        VALID_INSTALL_PLATFORM=$(jq -r ".games.nethack_variants[] | select(.name==\"$GAME_NAME\") | .install_command_$PLATFORM" <"$ATH_DIR"/config.json)
        # If VALID_INSTALL_PLATFORM is not blank or equal to the word null, then we can install the game
        if [ -n "$VALID_INSTALL_PLATFORM" ] && [ "$VALID_INSTALL_PLATFORM" != "null" ]; then
          # If an installation method is available, then install the game
          DisplayInstallGameConfirmationMenu "$GAME_NAME"
          local res=$?
          if [ "$res" -eq 0 ]; then
            DisplayInstallGameInformationMenu "$GAME_NAME"
          fi
          exitStatus=$res
        else
          # If an installation method is not available, then display an error message
          DisplayErrorMessage "No installation method available for your platform."
          DisplayInstallGameInformationMenu "$GAME_NAME"
          exitStatus=$?
        fi
      # If option selection begins with "update", then it is the update option
      elif [[ "$OPTION_SELECTION" = "Update"* ]]; then
        echo "Update Unimplemented"
      # If option selection begins with "remove", then it is the remove option
      elif [[ "$OPTION_SELECTION" = "Remove"* ]]; then
        echo "Remove Unimplemented"
      # If option selection contains "exports", then it is the export option
      elif [[ "$OPTION_SELECTION" = "Setup Exports"* ]]; then
        echo "Setup Exports Unimplemented"
      fi

    fi
  done

  return $exitStatus
}

# Displays a dialog with a list of all variants from the config file
function DisplayNethackInstallManagementMenu() {
  local HEIGHT=18
  local WIDTH=40
  local CHOICE_HEIGHT=10
  local j
  local i
  declare -a INSTALL_MANAGEMENT_OPTIONS

  i=0                         #Index counter for adding to array
  j=0                         #Option menu value generator
  while IFS= read -r line; do # Read a line
    local letter
    NumberToLetter $j letter
    INSTALL_MANAGEMENT_OPTIONS[$i]=$letter
    ((j++))
    INSTALL_MANAGEMENT_OPTIONS[($i + 1)]=$line
    ((i = (i + 2)))
  done < <(jq -r '.games.nethack_variants[].name' <"$ATH_DIR/config.json")

  exec 3>&1
  local INSTALL_MANAGEMENT_CHOICE
  INSTALL_MANAGEMENT_CHOICE=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "Manage Nethack Installations" \
    --cancel-label "Back" \
    --menu "Choose a version to manage" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${INSTALL_MANAGEMENT_OPTIONS[@]}" \
    2>&1 1>&3)
  local exitStatus=$?
  exec 3>&-
  clear

  for i in "${!INSTALL_MANAGEMENT_OPTIONS[@]}"; do
    if [[ "${INSTALL_MANAGEMENT_OPTIONS[$i]}" = "${INSTALL_MANAGEMENT_CHOICE}" ]]; then
      local GAME_NAME="${INSTALL_MANAGEMENT_OPTIONS[$i + 1]}"
      DisplayInstallGameInformationMenu "$GAME_NAME"
      DisplayNethackInstallManagementMenu
    fi
  done

  return $exitStatus
}

# Displays the main menu
function DisplayMainMenu() {
  local HEIGHT=11
  local WIDTH=40
  local CHOICE_HEIGHT=4

  local MAIN_MENU_OPTIONS
  MAIN_MENU_OPTIONS=(
    A "Local Play"
    B "Remote Play"
    C "Manage Installs"
    Q "Quit"
  )

  local MAIN_MENU_CHOICE
  MAIN_MENU_CHOICE=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "Main Menu" \
    --cancel-label "Quit" \
    --menu "" $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${MAIN_MENU_OPTIONS[@]}" \
    2>&1 >/dev/tty)
  clear

  case $MAIN_MENU_CHOICE in
  A)
    echo "Unimplemented"
    sleep 1
    DisplayMainMenu
    ;;
  B)
    DisplayNethackRemotePlayMenu
    local res=$?
    if [ "$res" -eq 1 ]; then
      DisplayMainMenu
    fi
    ;;
  C)
    DisplayNethackInstallManagementMenu
    local res=$?
    if [ "$res" -eq 1 ]; then
      DisplayMainMenu
    fi
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
# Validate our config
ValidateConfig
# Display the main menu
DisplayMainMenu
