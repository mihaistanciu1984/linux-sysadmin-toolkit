# Mount a Remote Directory with SSHFS

SSHFS allows a remote directory to be mounted locally through an encrypted SSH connection.

After mounting, remote files can be accessed like files from a local directory.

## Example configuration

This procedure uses the following example values:

| Setting | Value |
|---|---|
| Remote server | `192.0.2.10` |
| SSH user | `example-user` |
| Remote directory | `/home/example-user/shared` |
| Local mount point | `~/remote-share` |

Replace these values with the correct information for your environment.

## 1. Install SSHFS

### Ubuntu or Debian

```bash
sudo apt update
sudo apt install -y sshfs
```

### Oracle Linux, Rocky Linux or AlmaLinux

```bash
sudo dnf install -y fuse-sshfs
```

If the package is unavailable on Oracle Linux 8, enable the EPEL repository:

```bash
sudo dnf install -y oracle-epel-release-el8
sudo dnf install -y fuse-sshfs
```

Verify the installation:

```bash
sshfs --version
```

## 2. Test the SSH connection

Before using SSHFS, verify that SSH access works:

```bash
ssh example-user@192.0.2.10
```

After the connection succeeds, exit the remote server:

```bash
exit
```

## 3. Check the remote directory

Connect to the remote server:

```bash
ssh example-user@192.0.2.10
```

Create the directory if it does not exist:

```bash
mkdir -p /home/example-user/shared
```

Check its permissions:

```bash
ls -ld /home/example-user/shared
```

The SSH user must have permission to access and write to this directory.

If this is a dedicated folder owned by `example-user`, permissions can be configured with:

```bash
sudo chown example-user:example-user /home/example-user/shared
sudo chmod 750 /home/example-user/shared
```

Do not run `chown` on an existing shared or system directory without first checking its current owner.

Exit the remote server:

```bash
exit
```

## 4. Create the local mount point

Run this command on the local computer:

```bash
mkdir -p ~/remote-share
```

The local user should own the mount point:

```bash
ls -ld ~/remote-share
```

If necessary, correct the ownership:

```bash
sudo chown "$USER":"$USER" ~/remote-share
```

## 5. Mount the remote directory

```bash
sshfs example-user@192.0.2.10:/home/example-user/shared ~/remote-share
```

Enter the SSH password when requested.

Command explanation:

- `example-user` is the user from the remote server.
- `192.0.2.10` is the remote server address.
- `/home/example-user/shared` is the remote directory.
- `~/remote-share` is the local mount point.

## 6. Verify the mount

```bash
mountpoint ~/remote-share
```

List the remote files:

```bash
ls -la ~/remote-share
```

Test write access:

```bash
touch ~/remote-share/sshfs-write-test.txt
```

Verify the test file:

```bash
ls -l ~/remote-share/sshfs-write-test.txt
```

Remove the test file:

```bash
rm ~/remote-share/sshfs-write-test.txt
```

If `touch` returns `Permission denied`, check the permissions of the remote directory.

## 7. Unmount the directory

For systems using FUSE 3:

```bash
fusermount3 -u ~/remote-share
```

For older systems:

```bash
fusermount -u ~/remote-share
```

Alternatively:

```bash
umount ~/remote-share
```

Verify that it is no longer mounted:

```bash
mountpoint ~/remote-share
```

## Optional: Use an SSH key

SSH keys avoid entering the password every time the directory is mounted.

Create a key:

```bash
ssh-keygen -t ed25519
```

Copy the public key to the remote server:

```bash
ssh-copy-id example-user@192.0.2.10
```

Test the connection:

```bash
ssh example-user@192.0.2.10
```

Mount the remote directory:

```bash
sshfs example-user@192.0.2.10:/home/example-user/shared ~/remote-share
```

## Troubleshooting

### Connection refused

Check that SSH is running on the remote server:

```bash
sudo systemctl status ssh
```

On some distributions, the service is named `sshd`:

```bash
sudo systemctl status sshd
```

### Permission denied

Verify the remote directory permissions:

```bash
ssh example-user@192.0.2.10
ls -ld /home/example-user/shared
```

### Transport endpoint is not connected

Force the disconnected mount to unmount:

```bash
fusermount3 -uz ~/remote-share
```

Mount it again:

```bash
sshfs example-user@192.0.2.10:/home/example-user/shared ~/remote-share
```

## References

- [SSHFS official project](https://github.com/libfuse/sshfs)
- [DigitalOcean SSHFS guide](https://www.digitalocean.com/community/tutorials/how-to-use-sshfs-to-mount-remote-file-systems-over-ssh)