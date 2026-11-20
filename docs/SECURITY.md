# Security Specification & Compliance Controls

This document details the security posture, hardening baselines, and identity controls implemented across the multi-cloud golden image pipeline.

---

## 1. Compliance Alignment

The configuration implements recommendations aligned with:
- **CIS Ubuntu Linux 22.04 LTS Benchmark v1.0.0 (Level 1 Server)**
- **NIST SP 800-53 Rev. 5** (Identification and Authentication, Access Control, Audit and Accountability)
- **SOC 2 Type II** (Common Criteria 6.1, 6.6, 6.8)

---

## 2. Kernel & Network Stack Controls (`/etc/sysctl.d/99-cis-hardening.conf`)

| Parameter | Value | Security Impact | CIS Recommendation |
|---|---|---|---|
| `kernel.randomize_va_space` | `2` | Full Address Space Layout Randomization (ASLR) against buffer overflow exploits | CIS 1.5.3 |
| `fs.suid_dumpable` | `0` | Prohibits setuid core dumps to prevent sensitive credential dumps in memory | CIS 1.5.1 |
| `kernel.kptr_restrict` | `2` | Hides kernel symbols and pointers from unprivileged users | CIS 1.5.2 |
| `kernel.dmesg_restrict` | `1` | Prevents unprivileged access to kernel dmesg log buffer | Hardening best practice |
| `net.ipv4.ip_forward` | `0` | Disables packet routing unless host is explicitly configured as gateway | CIS 3.1.1 |
| `net.ipv4.conf.all.rp_filter` | `1` | Enables strict reverse-path filtering to block IP address spoofing | CIS 3.2.7 |
| `net.ipv4.conf.all.accept_redirects` | `0` | Rejects ICMP redirect packets (prevents routing table poisoning) | CIS 3.2.2 |
| `net.ipv4.conf.all.send_redirects` | `0` | Blocks transmission of ICMP redirects | CIS 3.2.1 |
| `net.ipv4.conf.all.log_martians` | `1` | Logs packets with impossible/spoofed source IP addresses | CIS 3.2.8 |
| `net.ipv4.tcp_syncookies` | `1` | Enables TCP SYN Cookies to mitigate SYN flood denial of service | CIS 3.2.9 |

---

## 3. OpenSSH Daemon Hardening (`/etc/ssh/sshd_config`)

- **Protocol**: Protocol 2 strictly enforced.
- **Root Login**: `PermitRootLogin no` (root authentication over SSH is permanently forbidden).
- **Authentication**: `PasswordAuthentication no` (passwords disabled; public-key cryptography only).
- **Empty Passwords**: `PermitEmptyPasswords no`.
- **Brute Force Protection**: `MaxAuthTries 3`.
- **Session Timeout**: `ClientAliveInterval 300` and `ClientAliveCountMax 2` (disconnects idle sessions after 10 minutes).
- **Modern Cryptographic Suites**:
  - **Ciphers**: `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, `aes128-gcm@openssh.com`
  - **MACs**: `hmac-sha2-512-etm@openssh.com`, `hmac-sha2-256-etm@openssh.com`
  - **Key Exchange (KEX)**: `curve25519-sha256`, `diffie-hellman-group16-sha512`

---

## 4. Auditing & Accountability (`auditd`)

- **Audit Daemon (`/etc/audit/auditd.conf`)**:
  - Buffer size set to 8192 to prevent dropped audit records under peak loads.
  - Action on disk full set to `SUSPEND` to prevent silent logging failures.
- **Audit Rules (`/etc/audit/rules.d/cis.rules`)**:
  - System time changes (`settimeofday`, `clock_settime`, `adjtimex`).
  - Identity modification (`/etc/passwd`, `/etc/shadow`, `/etc/group`).
  - Network locale modification (`/etc/hosts`, `/etc/network`).
  - Discretionary Access Control (DAC) alterations (`chmod`, `chown`, `setxattr`).
  - Unauthorized file access events (system calls returning `-EACCES` or `-EPERM`).
  - Privileged command executions (`/usr/bin/sudo`, `/usr/bin/su`).
  - Kernel module loading/unloading (`insmod`, `rmmod`, `modprobe`).
  - **Rule Immutability**: Appends `-e 2` as the final directive, locking the audit rules until next system reboot.

---

## 5. Account Security & PAM Quality

- **`pam_pwquality`**: Minimum password length of 14 characters, requiring lowercase, uppercase, digits, and special characters.
- **`pam_faillock`**: Locks accounts for 15 minutes upon 5 consecutive failed login attempts.
- **Core Dumps**: Disabled via `/etc/security/limits.d/10-disable-core-dumps.conf`.
- **System Umask**: Set to `027` in `/etc/login.defs`, ensuring newly created files are unreadable by untrusted users.

---

## 6. Automated Verification (Goss Test Suite)

Before any image is packaged:
1. Goss executes in-memory assertion tests against the active instance.
2. Verifies:
   - All CIS sysctl parameters are active in `/proc/sys`.
   - Security services (`auditd`, `ufw`, `systemd-timesyncd`) are running.
   - Legacy packages (`telnet`, `rsh`, `talk`, `nis`) are completely absent.
   - SSH configuration satisfies strict cryptographic constraints.
3. If ANY assertion fails, Packer terminates the build process with code 1 and **deletes the temporary machine**, guaranteeing defective or vulnerable images are never published.

---

## 7. Golden Image Sanitization (Secret Leakage Prevention)

To guarantee that each machine launched from the golden image has a unique identity and zero leaked secrets:
- `/etc/machine-id` is truncated to 0 bytes.
- `/var/lib/dbus/machine-id` is linked to `/etc/machine-id`.
- SSH host keys (`/etc/ssh/ssh_host_*`) are deleted (regenerated automatically by cloud-init upon first boot).
- Cloud-init seed and logs are reset via `cloud-init clean --logs --seed`.
- Temporary Packer user and authorized SSH keys are removed.
- All log files in `/var/log` are truncated.
- Shell histories (`.bash_history`) are purged.
