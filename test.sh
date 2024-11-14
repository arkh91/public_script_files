#!/bin/bash

get_distro_release() {
  if [ -f /etc/os-release ]; then
    # Most modern Linux distributions, including openSUSE and AlmaLinux, have this file
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
    # For Red Hat-based systems, including CentOS
    distro=$(cat /etc/redhat-release | awk '{print $1}')
    release=$(cat /etc/redhat-release | awk '{print $3}')
    echo "Distro: $distro"
    echo "Release: $release"
  elif [ -f /etc/almalinux-release ]; then
    # AlmaLinux
    echo "Distro: AlmaLinux"
    echo "Release: $(cat /etc/almalinux-release | awk '{print $3}')"
  elif [ -f /etc/SuSE-release ]; then
    # For openSUSE systems
    distro=$(cat /etc/SuSE-release | grep '^NAME' | awk -F= '{print $2}')
    release=$(cat /etc/SuSE-release | grep '^VERSION' | awk -F= '{print $2}')
    echo "Distro: openSUSE$distro"
    echo "Release: $release"
  elif [ "$(uname -s)" = "FreeBSD" ]; then
    # For FreeBSD systems
    echo "Distro: FreeBSD"
    echo "Release: $(freebsd-version)"
  else
    echo "Distro and release information not found"
  fi
}

# Call the function
get_distro_release


# Call the function
get_distro_release
