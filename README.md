# podman-volume-backup

Systemd timer and service to perform regular backups of podman volumes.
Includes support for containers managed via Quadlet.
Leverages `podman volume export` to generate `tar` backups of volumes, then `gzip` compressed.

## Installation

The systemd units expect the `backup-volumes.sh` script to be located at `$HOME/bin`.

### Rootless

Execute the following as the non-root user you use to run your containers:

```bash
git clone https://github.com/chadweimer/podman-volume-backup
ls -s ~/bin/backup-volumes.sh podman-volume-backup/backup-volumes.sh
ln -s ~/.config/systemd/user/backup-volumes.timer podman-volume-backup/backup-volumes.timer
ln -s ~/.config/systemd/user/backup-volumes.service podman-volume-backup/backup-volumes.sevice
systemctl --user enable --now backup-volumes.timer
```

### Rootful

Execute the following as root:

```bash
git clone https://github.com/chadweimer/podman-volume-backup
ls -s /root/bin/backup-volumes.sh podman-volume-backup/backup-volumes.sh
ln -s /etc/systemd/system/backup-volumes.timer podman-volume-backup/backup-volumes.timer
ln -s /etc/systemd/system/backup-volumes.service podman-volume-backup/backup-volumes.sevice
systemctl enable --now backup-volumes.timer
```

## Usage

The backup script will backup any volumes listed in the `dev.cwmr.volumes-to-backup` label on a container. Multiple volumes can be specified, separated by commas.
The container with the label will be stopped first, and then restared afterward.

> NOTE: Does not currently support stopping other containers (e.g., stopping an application container that uses the database container that is being backed up).

> WARNING: Not tested with containers inside pods.

Backups are written to `~/backups/<volume-name>.tar.gz`. This is not currently configurable.

Example:
```yaml
version: '3'

name: backup-example

services:
  app:
    image: ubuntu
    name: my-container
    labels:
      - dev.cwmr.volumes-to-backup=backup-example_vol1,backup-example_vol2
    volumes:
      - vol1:/some/container/path
      - vol2:/another/container/path

volumes:
  vol1:
  vol2:
```

### Restoring a backup

This repository provides a script to easily restore a backup to a container.

```bash
cd ~/backups
/path/to/restore-volumes.sh --container <container-name>
```

The script uses the same `dev.cwmr.volumes-to-backup` label to determine the volumes to restore.
By default the script will look in the working directory for the backups.
You can also specify the path to the location of your backups directory via the `-d|--dir` flag. E.g.,,

```bash
/path/to/restore-volumes.sh --container <container-name> --dir /path/to/backups/dir
```

Run the script as root for rootful containers.

> NOTE: The restore script does NOT clear the existing contents of the volume before executing `podman volume import`. It is expected to be run on freshly created volumes.
