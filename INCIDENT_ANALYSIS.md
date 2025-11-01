# NixOS Configuration Incident Analysis
**Date**: November 1, 2025  
**Severity**: Critical - SSH lockout on production server  
**Status**: Root cause identified, fix applied, awaiting verification

---

## Executive Summary

A NixOS configuration for an SFTP chrooted user caused catastrophic permission failures during system activation, resulting in SSH lockout on multiple servers (gemini and midship). Users were unable to log in and the system reported "Failed to spawn user activation for chris / Caused by: Permission denied (os error 13)". Rescue boot was required to restore access.

**Root Cause**: The user configuration set `home = "/"` combined with `isNormalUser = true`, causing NixOS's user management subsystem to attempt operating on the root filesystem during activation, triggering cascading permission conflicts.

---

## Timeline of Events

1. **Initial Configuration**: Created `hosts/gemini/services/sven.nix` for SFTP-only chrooted user
2. **Deployment to Gemini**: Ran `sudo nixos-rebuild switch --flake .#gemini`
3. **Activation Failure**: System activation succeeded partially, but user activation failed with permission errors
4. **SSH Lockout**: Unable to SSH into gemini - authentication completely failed
5. **Secondary Impact**: Same configuration was staged on midship but not yet deployed
6. **Recovery**: Required rescue boot to regain access and fix permissions
7. **Root Cause Analysis**: Identified problematic user configuration pattern

---

## Technical Deep Dive

### The Problematic Configuration

```nix
users.users.${sftpUser} = {
  isNormalUser = true;        # ← PROBLEM: Enables home directory management
  group = sftpUser;
  home = "/";                 # ← CRITICAL PROBLEM: Points to root filesystem
  shell = "${pkgs.shadow}/bin/nologin";
  # ... rest of config
};
```

### Why This Failed

1. **isNormalUser = true Behavior**:
   - NixOS treats users with `isNormalUser = true` as regular login users
   - Automatically enables home directory creation and management
   - Triggers systemd user service activation
   - Attempts to set up user environment files and permissions

2. **home = "/" Conflict**:
   - Setting home directory to `/` is semantically invalid for a managed user
   - NixOS user activation tries to ensure home directory exists and has correct permissions
   - Operating on `/` as a home directory causes permission checks/modifications on the root filesystem
   - This conflicts with existing system permissions and ownership

3. **Cascading Failure**:
   - During `nixos-rebuild switch`, the system activation phase succeeded
   - User activation phase attempted to spawn user services for all users
   - When processing the `sven` user, it tried to operate on `/` as a home directory
   - This likely triggered permission changes or checks that affected other users
   - The `chris` user activation subsequently failed with "Permission denied (os error 13)"
   - SSH authentication depends on user activation succeeding
   - Result: Complete SSH lockout

### Additional Risk Factors

The configuration also included tmpfiles rules that could have contributed:

```nix
systemd.tmpfiles.rules = [
  "d ${chrootDir} 0755 root root - -"  # Creates /var/www/sven
  "d ${chrootDir}/html 02775 ${sftpUser} ${sftpUser} - -"
];
```

If `/var/www/sven` existed with different ownership, tmpfiles would attempt to fix it during activation, potentially causing additional permission conflicts. However, this is likely a secondary issue compared to the `home = "/"` problem.

---

## The Fix

### Applied Changes

Changed the user configuration from a "normal user" to a "system user":

```nix
users.users.${sftpUser} = {
  isSystemUser = true;        # ← FIX: No home directory management
  group = sftpUser;
  # home = "/";               # ← FIX: Removed entirely
  shell = "${pkgs.shadow}/bin/nologin";
  # ... rest of config
};
```

### Why This Works

1. **isSystemUser = true**:
   - Designed for service accounts and daemon users
   - Does NOT trigger automatic home directory creation/management
   - Does NOT spawn user services during activation
   - Does NOT attempt to set up user environment

2. **No home Directory Specified**:
   - System users don't require a home directory for chrooted SFTP
   - The OpenSSH `ChrootDirectory` setting handles where the user lands
   - The `ForceCommand internal-sftp -d /html` starts them in the correct location
   - Eliminates any possibility of NixOS trying to manage filesystem permissions

3. **Chroot Isolation**:
   - User never sees the real filesystem - always chrooted to `/var/www/sven`
   - The `-d /html` flag makes them start in `/var/www/sven/html` (appears as `/html` to them)
   - No login shell, no interactive access - SFTP protocol only
   - Home directory concept is irrelevant in this use case

---

## Questions for Peer Review

### Configuration Validation

1. **Is `isSystemUser = true` the correct approach for SFTP-only chrooted users in NixOS?**
   - Alternative: Could we use `createHome = false` with `isNormalUser = true`?
   - Trade-offs: Would this prevent the activation issues?

2. **Are there edge cases where a system user might still cause issues?**
   - What if the user needs password authentication?
   - Does `initialPassword` or `hashedPassword` work with system users?

3. **Tmpfiles rules safety**:
   - Should we use `Z` (set ownership/permissions only if path exists) instead of `d` (create if missing)?
   - Example: `"Z ${chrootDir} 0755 root root - -"` vs `"d ${chrootDir} 0755 root root - -"`

### SFTP Chroot Best Practices

4. **Is there a better pattern for SFTP chroots in NixOS?**
   - Should we be using a dedicated NixOS module instead of inline configuration?
   - Are there existing modules we should reference (like `services.openssh.sftpUsers` or similar)?

5. **Permission strategy verification**:
   - `/var/www/sven` → `0755 root:root` (correct for chroot root?)
   - `/var/www/sven/html` → `02775 sven:sven` (setgid bit appropriate?)
   - Does nginx really need to be in the sven group, or should we use ACLs?

### Deployment Safety

6. **How can we test NixOS configurations safely before deploying to production?**
   - Should we always use `nixos-rebuild test` first (doesn't update bootloader)?
   - Can we validate user activation without full deployment?
   - Are there tools to detect "dangerous" configuration patterns?

7. **Rollback strategy**:
   - Why didn't the previous generation's bootloader entry work?
   - Was the user activation failure preventing rollback?
   - Should we have a "break glass" configuration that's minimal and always safe?

### Broader Impact Assessment

8. **Did this affect the chris user directly, or was it collateral damage?**
   - The error was "Failed to spawn user activation for chris"
   - Was chris affected because user activation is sequential?
   - Or did the `/` home directory operations corrupt `/home/chris` permissions?

9. **Could this have affected other hosts?**
   - The configuration exists on gemini (deployed) and midship (staged)
   - Any other hosts with similar patterns?
   - Should we audit all user definitions across the flake?

---

## Recommended Actions

### Immediate

- [x] Fix applied to `hosts/gemini/services/sven.nix`
- [x] Fix applied to `hosts/midship/services/sven.nix`
- [ ] Test build configuration: `nix build .#nixosConfigurations.gemini.config.system.build.toplevel --no-link`
- [ ] Deploy to midship first (less critical): `ssh midship 'cd ~/.nixos-config && git pull && sudo nixos-rebuild switch --flake .#midship'`
- [ ] Deploy to gemini (if midship successful): `ssh gemini 'cd ~/.nixos-config && git pull && sudo nixos-rebuild switch --flake .#gemini'`

### Short Term

- [ ] Audit all user definitions across all hosts for similar patterns
- [ ] Search for any other `home = "/"` occurrences
- [ ] Search for any other SFTP/chroot configurations
- [ ] Document this pattern in project copilot-instructions.md

### Long Term

- [ ] Consider creating a custom NixOS module for SFTP chroot users
- [ ] Implement pre-deployment validation checks
- [ ] Set up VM-based testing for configuration changes
- [ ] Create monitoring/alerting for user activation failures

---

## Files Modified

- `/home/chris/.nixos-config/hosts/gemini/services/sven.nix`
- `/home/chris/.nixos-config/hosts/midship/services/sven.nix`

**Changes**: 
- Line ~17: `isNormalUser = true` → `isSystemUser = true`
- Line ~19: Removed `home = "/"; # Irrelevant for chrooted SFTP`
- Added comment explaining system user rationale

---

## Testing Checklist

Before deploying the fix:

- [ ] Configuration builds successfully: `nix build .#nixosConfigurations.gemini.config.system.build.toplevel --no-link`
- [ ] No syntax errors reported
- [ ] Git changes committed and pushed

After deploying to midship (test server):

- [ ] System activation completes without errors
- [ ] SSH access remains functional for chris user
- [ ] User `sven` exists: `id sven`
- [ ] Chroot directory created: `ls -ld /var/www/sven /var/www/sven/html`
- [ ] Set password: `sudo passwd sven`
- [ ] SFTP login works: `sftp sven@midship`
- [ ] Chrooted correctly: `sftp> pwd` should show `/html`
- [ ] File upload works: `sftp> put testfile.txt`

After deploying to gemini (production):

- [ ] Same checklist as midship
- [ ] Verify nginx integration (if applicable)
- [ ] Test from external client (FileZilla/Cyberduck)

---

## Additional Context

### Original Use Case

The sven user was created to provide SFTP-only access for file uploads to a web-accessible directory. Requirements:

- No shell access (security)
- Chrooted to prevent filesystem exploration
- Files uploaded should be readable by nginx (web server)
- Support password authentication for GUI SFTP clients

### Environment Details

- **Host**: gemini (OVH dedicated server, 147.135.105.6)
- **NixOS Version**: Flake-based, using nixpkgs 24.05+
- **Affected User**: chris (primary admin user, SSH key auth)
- **New User**: sven (SFTP-only chrooted user)

### Related Configurations

This incident was part of a larger effort involving:

1. Fixing a user definition merging bug (separate issue - resolved)
2. Migrating services from gemini to midship
3. Setting up SFTP infrastructure for multiple hosts

The user definition bug was unrelated but happened around the same time:
- Original pattern: `users.users = { nginx = {}; dayz = {}; }` (WRONG - replaces entire attr set)
- Correct pattern: `users.users.nginx = {}; users.users.dayz = {};` (merges with base.nix)

---

## Conclusion

This incident demonstrates the importance of understanding NixOS's user management semantics. The distinction between `isNormalUser` and `isSystemUser` is critical, and seemingly innocuous settings like `home = "/"` can have catastrophic consequences during system activation.

The fix is straightforward, but we need peer review to ensure:
1. This is the correct approach for SFTP chroot users
2. No other edge cases exist
3. Similar patterns don't exist elsewhere in the codebase
4. Testing strategy is sufficient before production deployment

**Confidence Level**: High that this fixes the immediate issue, but seeking validation on best practices and long-term safety.
