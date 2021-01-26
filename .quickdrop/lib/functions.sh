#!/usr/bin/env bash

export PATH=/usr/local/bin:$PATH

[[ -f ~/.quickdrop/config ]] && . ~/.quickdrop/config

watchlog=~/.quickdrop/watch.log

die() {
  echo >&2 "Error: $@"
  exit 1
}

fail() {
  afplay /System/Library/Sounds/Basso.aiff&
  osascript -e "display dialog \"Quickdrop Failed$1\" with icon caution" > /dev/null 2>&1
  return 1
}

notify() {
  local script="display notification \"$2\" with title \"$1\""
  if [[ $3 ]]; then
    script="$script sound name \"$3\""
  fi
  osascript -e "$script"
}

check_config() {
  [[ $QD_PROFILE ]] || die "QD_PROFILE not configured"
  [[ $QD_BUCKET ]] || die "QD_BUCKET not configured"
}

qdls() {
  check_config
  aws --profile $QD_PROFILE s3 ls --recursive s3://$QD_BUCKET
}

qdrm() {
  check_config
  aws --profile $QD_PROFILE s3 rm --recursive s3://$QD_BUCKET/$1/
}

qdup() {
  local path="$1"
  [[ $path ]] || die "Expected path"
  [[ -f "$path" ]] || die "No such file: $path"
  check_config
  local filename="$(basename "$path")"
  local m=32768
  local randint=$((RANDOM+RANDOM*m+RANDOM*m*m+RANDOM*m*m*m))
  local randid=$(~/.quickdrop/lib/bashids -e $randint)
  local s3_dest_path="s3://$QD_BUCKET/$randid/"
  local content_disposition="attachment; filename=\"$filename\""
  local content_type=""
  local lcfn="$(echo "$filename" | tr '[A-Z]' '[a-z]')"
  if [[ $lcfn =~ \.(txt|css|htm|html|csv|tsv|json|js|sh|bat|cmd|java|ts)$ ]]; then
    content_type="text/plain; charset=utf-8"
  fi
  if [[ $lcfn =~ \.(png|jpg|jpeg|gif|webp|mp4|mov|mpeg|webm|wav|ogg|txt|md|css|html|htm|csv|tsv|json|js|sh|cmd|java|py|rb|yaml)$ ]]; then
    content_disposition="inline"
  fi
  local result
  if [[ -z $content_type ]]; then
    result=$(aws --profile $QD_PROFILE s3 cp "$path" $s3_dest_path --acl public-read --content-disposition "$content_disposition" 2>&1)
  else
    result=$(aws --profile $QD_PROFILE s3 cp "$path" $s3_dest_path --acl public-read --content-type "$content_type" --content-disposition "$content_disposition" 2>&1)
  fi
  if [[ $? == 0 ]]; then
    local urlsafe_filename=$(echo "$result" | sed 's|.*s3://.*/||g')
    echo "https://$QD_BUCKET.s3.amazonaws.com/$randid/$urlsafe_filename"
  else
    result=${result/// }
    echo "$result"
    return 1
  fi
}

qdone() {
  # path gui last
  if [[ $1 ]]; then
    local fn="$(basename "$1")"
    if [[ $2 == gui ]]; then
      notify "Uploading" "$fn"
    fi
    echo "Uploading $1"
  fi
  local result
  result=$(qdup "$1" 2>&1)
  if [[ $? == 0 ]]; then
    if [[ $3 == true ]]; then
      echo -n $result | pbcopy
      if [[ $2 == gui ]]; then
        notify "Upload complete" "URL copied to clipboard" "Morse"
      fi
      echo "Uploaded to $result"
    fi
  else
    if [[ $2 == gui ]]; then
      fail "$result"
    fi
    echo "Upload failed: $result"
    return 1
  fi
}

echo_red() {
  echo -e "\e[1m\e[38;5;1m$1\e[m"
}

echo_yellow() {
  echo -e "\e[1m\e[33;5;1m$1\e[m"
}

echo_green() {
  echo -e "\e[1m\e[38;5;2m$1\e[m"
}

echo_bold() {
  echo -e "\e[1m$1\e[m"
}

require_command() {
  echo -n "Checking for $1.."
  command -v $1 > /dev/null 2>&1
  if [[ $? == 0 ]]; then
    echo "ok"
  else
    echo_yellow "not found"
    echo
    echo_yellow "ATTENTION: Quickdrop requires $2 to be installed."
    echo
    echo "Please install it, then run ~/.quickdrop/bin/qdsetup"
    if [[ $2 == aws-cli ]]; then
      echo "See https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html"
    else
      echo "Homebrew users may install it via brew install $2"
    fi
    exit 1
  fi
}

require_config() {
  echo -n "Checking $1.."
  if [[ $1 == "QD_PROFILE" ]]; then
    if [[ $QD_PROFILE ]]; then
      echo "ok (value = '$QD_PROFILE')"
      return
    fi
  elif [[ $1 == "QD_BUCKET" ]]; then
    if [[ $QD_BUCKET ]]; then
      echo "ok (value = '$QD_BUCKET')"
      return
    fi
  fi
  echo_yellow "not set"
  echo
  echo_yellow "ATTENTION: Quickdrop requires $1 to be set."
  echo
  echo "Please configure it in ~/.quickdrop/config, then run ~/.quickdrop/bin/qdsetup"
  exit 1
}

qdsetup() {
  echo_bold "---------------"
  echo_bold "Quickdrop Setup"
  echo_bold "---------------"
  require_command realpath coreutils
  require_command fswatch fswatch
  require_command aws aws-cli
  require_config QD_PROFILE
  require_config QD_BUCKET
  echo -n "Checking S3 connectivity.."
  local result
  result=$(aws --profile $QD_PROFILE s3 ls s3://$QD_BUCKET 2>&1)
  if [[ $? != 0 ]]; then
    echo_yellow "failed"
    echo
    echo_yellow "ATTENTION: Unable to list contents of '$QD_BUCKET' bucket"
    echo
    echo "The command we attempted to run was:"
    echo
    echo "> aws --profile $QD_PROFILE s3 ls s3://$QD_BUCKET"
    echo
    echo "The error was:"
    echo_red "$result"
    echo
    echo "Please resolve the error, then run ~/.quickdrop/bin/qdsetup"
    exit 1
  fi
  echo "ok"
  echo -n "Adding qdwatch launchd agent.."
  cd ~/Library/LaunchAgents
  if [[ ! -e com.github.cwilper.quickdrop.plist ]]; then
    ln -s ~/.quickdrop/lib/com.github.cwilper.quickdrop.plist
    echo "ok"
  else
    echo "already added"
  fi
  echo -n "Starting qdwatch.."
  ~/.quickdrop/bin/qdstop
  ~/.quickdrop/bin/qdstart
  echo "ok"
  echo -n "Checking for command line utilities.."
  which qdup > /dev/null 2>&1
  if [[ $? != 0 ]]; then
    echo_yellow "not found in PATH"
    echo
    echo_yellow "ATTENTION: Quickdrop command line utilities are not in your PATH."
    echo
    echo "To add them, put something like the following in your shell startup file:"
    echo "(e.g. .bashrc)"
    echo
    echo_bold "export PATH=~/.quickdrop/bin:\$PATH"
    echo
    echo "NOTE: This is an OPTIONAL step for convenience only."
  else
    echo "found in PATH"
  fi
  echo_green "Setup complete!"
}

qdwatch() {
  local dir="$1"
  if [[ -z $dir ]]; then
    dir=~/Quickdrop
    [[ -d ~/Quickdrop ]] || mkdir ~/Quickdrop
  fi
  [[ -d $dir ]] || die "Directory not found: $dir"
  dir="$(realpath "$dir")"
  echo "Watching $dir"
  while read -r path; do
    if [[ -f $path && ! $path =~ "/\.DS_Store$" ]]; then
      path="$(realpath "$path")"
      local parent="$(dirname "$path")"
      if [[ $parent == $dir ]]; then
        local count=$(find "$dir" -type f -depth 1 ! -name .DS_Store | wc -l | awk '{print $1}')
        local last=false
        [[ $count == 1 ]] && last=true
        qdone "$path" gui $last
        if [[ $? == 0 ]]; then
          rm -f "$path"
        fi
      fi
    fi
  done < <(find "$dir" -type f -depth 1 ! -name .DS_Store ; fswatch --event=IsFile "$dir")
}
