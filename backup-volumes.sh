#!/bin/bash
set -e

# Usage: backup-volumes.sh [-o|--output <backups-directory>]


OUTPUT_PATH=$PWD
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUTPUT_PATH="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

#IFS=$'\n' containers_to_backup=( $(podman ps -q) )
IFS=$'\n' containers_to_backup=( $(podman ps -q --filter label=dev.cwmr.volumes-to-backup) )

# Make sure destination path exists
mkdir -p $OUTPUT_PATH

for container in "${containers_to_backup[@]}"
do
  echo -e "---\nBacking up volumes for $container"

  IFS=$' ' volumes_to_backup=( $(podman container inspect --format '{{ join (split (index .Config.Labels "dev.cwmr.volumes-to-backup") ",") " " }}' $container) )
  service=$(podman container inspect --format '{{ .Config.Labels.PODMAN_SYSTEMD_UNIT }}' $container)

  # Stop the service before exporting
  echo "Stopping $container..."
  {
    echo "Trying via systemd $service..."
    systemctl --user stop $service
  } || {
    echo "Systemd failed. Trying via podman..."
    podman stop $container
  }
  echo "Stopped $container."

  # Backup the volumes
  {
    for volume in "${volumes_to_backup[@]}"
    do
      echo "Exporting $volume..."
      podman volume export $volume | gzip > $OUTPUT_PATH/$volume.tar.gz
      echo "Exported $volume to $OUTPUT_PATH/$volume.tar.gz."
    done
  } || echo "Failed to backup all volumes for $container."

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

done
