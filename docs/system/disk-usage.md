# Linux Disk Usage Troubleshooting

## Display filesystem usage

```bash
df -hT
# Display inode usage
df -ih

# Find the largest directories
sudo du -xhd1 / 2>/dev/null | sort -h

#Find files larger than 1 GB
sudo find / -xdev -type f -size +1G -printf '%s %p\n' 2>/dev/null |
    sort -nr |
    numfmt --field=1 --to=iec


#Check deleted files still opened by processes
sudo lsof +L1

#Review log usage
sudo journalctl --disk-usage
sudo du -sh /var/log/*