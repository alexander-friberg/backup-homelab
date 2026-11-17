# ansible-backup-update

Ansible playbooks that back up chosen paths on a Linux server and update its packages, either on demand or as a weekly cron job.

Works on Debian/Ubuntu, RHEL/Fedora and Arch.

## Requirements

- Ansible with the `community.general` collection:
  ```sh
  ansible-galaxy collection install community.general
  ```
- SSH access to the server, with a user that can use sudo

## Setup

1. Copy `inventory.ini.example` to `inventory.ini` and add your server:
   ```ini
   [servers]
   myserver ansible_host=192.168.1.10 ansible_user=youruser
   ```
2. Put the sudo password in an encrypted vault:
   ```sh
   echo 'your-vault-password' > ~/.ansible/vault_pass && chmod 600 ~/.ansible/vault_pass
   ansible-vault create group_vars/servers/vault.yml
   # contents: ansible_become_password: your-sudo-password
   ```
3. Edit `backup_config.yml` to set the paths to back up, how many archives to keep, and the cron schedule.

## Usage

| Command | What it does |
| --- | --- |
| `ansible-playbook playbook.yml` | Backs up now, downloads the archive to `./backups`, updates packages and reboots if needed |
| `ansible-playbook schedule.yml` | Installs a weekly root cron job that does the backup and update on the server. Run it again after changing the config |
| `./check.sh` | Checks that the cron job, script and recent backups look healthy |

Cron runs keep their backups on the server only, in `remote_backup_dir`. Their output is logged to `cron_log`.
