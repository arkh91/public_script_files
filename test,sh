#!/bin/bash

get_distro_release() {
  if [ -f /etc/os-release ]; then
    # Most modern Linux distributions have this file
    . /etc/os-release
    echo "Distro: $NAME"
    echo "Release: $VERSION"
  elif [ -f /etc/lsb-release ]; then
    # Some older distributions have this file
    . /etc/lsb-release
    echo "Distro: $DISTRIB_ID"
    echo "Release: $DISTRIB_RELEASE"
  elif [ -f /etc/debian_version ]; then
    # For Debian-based systems without os-release
    echo "Distro: Debian"
    echo "Release: $(cat /etc/debian_version)"
  elif [ -f /etc/redhat-release ]; then
    # For Red Hat-based systems
    echo "Distro: $(cat /etc/redhat-release | awk '{print $1}')"
    echo "Release: $(cat /etc/redhat-release | awk '{print $3}')"
  else
    echo "Distro and release information not found"
  fi
}

# Call the function
get_distro_release
