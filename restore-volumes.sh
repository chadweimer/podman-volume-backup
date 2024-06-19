#!/bin/bash
set -e

# Usage: restore-volumes.sh -c|--container <container-name> [-d|--dir <backups-directory>]


container=""
backups_path=$PWD
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--container)
      container="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--dir)
      backups_path="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if test -z "$container"; then
    echo "A container must be specified."
    exit 1
fi

echo -e "---\nRestoring volumes for $container"

IFS=$' ' volumes_to_backup=( $(podman container inspect --format '{{ join (split (index .Config.Labels "dev.cwmr.volumes-to-backup") ",") " " }}' $container) )
service=$(podman container inspect --format '{{ .Config.Labels.PODMAN_SYSTEMD_UNIT }}' $container)

# Stop the service before importing
echo "Stopping $container..."
{
  echo "Trying via systemd $service..."
  systemctl --user stop $service
} || {
  echo "Systemd failed. Trying via podman..."
  podman stop $container
}
echo "Stopped $container."

# Restore the volumes
{
  for volume in "${volumes_to_backup[@]}"
  do
    echo "Importing $volume..."
    cat $backups_path/$volume.tar.gz | podman volume import $volume -
    echo "Imported $volume from $backups_path/$volume.tar.gz."
  done
} || echo "Failed to restore all volumes for $container."

# Restart the service
echo "Restarting $container..."
{
  echo "Trying via systemd $service..."
  systemctl --user start $service
} || {
  echo "Systemd failed. Trying via podman..."
  podman start $container
}
echo "Successfully restarted $container."
