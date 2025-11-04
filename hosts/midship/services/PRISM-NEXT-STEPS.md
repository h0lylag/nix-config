# Prism Django - Next Steps

## What Was Created

1. **`/home/chris/.nixos-config/hosts/midship/services/prism-django.nix`**
   - Simplified systemd service configuration
   - No complex module, just a straightforward service
   - Handles migrations and static collection in `preStart`

2. **`/home/chris/.nixos-config/hosts/midship/services/README-prism-django.md`**
   - Complete explanation of how Django works on NixOS
   - Architecture diagrams
   - Setup instructions
   - Troubleshooting guide

3. **Uses existing package**: `/home/chris/.nixos-config/pkgs/prism-django/default.nix`
   - Already built with all dependencies
   - Provides wrapper commands (prism-manage, prism-gunicorn, etc.)

## How collectstatic Works on NixOS

**The Challenge:**
- Application code lives in **read-only** `/nix/store/xxxxx-prism-django/`
- Can't write static files to application directory
- Need writable location for collected static files

**The Solution:**
1. Set `STATIC_ROOT=/var/lib/prism-django/staticfiles` (writable state directory)
2. Run `prism-collectstatic` in systemd `preStart` (before starting gunicorn)
3. WhiteNoise serves static files from this writable location
4. Static files are compressed and hashed for performance

**Why this works:**
- `collectstatic` reads source files from `/nix/store/` (read-only)
- Writes collected files to `/var/lib/prism-django/staticfiles/` (writable)
- WhiteNoise middleware intercepts `/static/*` requests and serves from `STATIC_ROOT`

## How migrate Works on NixOS

**The Challenge:**
- Application code is read-only in `/nix/store/`
- Can't write migration state to filesystem

**The Solution:**
1. Migration files are read from `/nix/store/` (read-only source)
2. Django connects to PostgreSQL database
3. Migration state written to `django_migrations` table in PostgreSQL (not filesystem)
4. No filesystem writes needed!

**Why this works:**
- Migrations only need to READ files (from read-only Nix store)
- All state is stored in PostgreSQL database
- Database is in `/var/lib/postgresql/` (writable, managed by postgresql service)

## Setup Checklist

- [ ] **1. Create secrets file**
  ```bash
  cd /home/chris/.nixos-config
  # Create secrets/prism-django.env with SECRET_KEY and POSTGRES_PASSWORD
  sops secrets/prism-django.env
  ```

- [ ] **2. Import service in midship/default.nix**
  ```nix
  imports = [
    ./services/prism-django.nix  # Add this line
  ];
  ```

- [ ] **3. Verify PostgreSQL is configured**
  - Check if `midship/services/postgresql.nix` exists
  - Or add PostgreSQL config to import

- [ ] **4. Build and deploy**
  ```bash
  # Test build first (from .nixos-config directory)
  nix build .#nixosConfigurations.midship.config.system.build.toplevel --no-link
  
  # Deploy to midship
  ssh midship
  cd ~/.nixos-config
  git pull
  sudo nixos-rebuild switch --flake .#midship
  ```

- [ ] **5. Create Django superuser**
  ```bash
  sudo -u prism prism-manage createsuperuser
  ```

- [ ] **6. Access application**
  - Direct: http://midship.local:8000/
  - Via nginx: http://prism.midship.local/ (if nginx enabled)

## Key Differences from Standard Deployment

| Aspect | Standard Deployment | NixOS Deployment |
|--------|-------------------|------------------|
| **Application location** | `/opt/prism/` or `/var/www/prism/` | `/nix/store/xxxxx-prism-django/` (read-only) |
| **Static files** | `python manage.py collectstatic` writes to app directory | Writes to `/var/lib/prism-django/staticfiles/` |
| **Database** | SQLite file or PostgreSQL | PostgreSQL only (recommended) |
| **Secrets** | `.env` file in app directory | sops-nix encrypted file |
| **Service management** | `systemctl` with custom unit file | NixOS declarative configuration |
| **Updates** | `git pull && systemctl restart` | `nixos-rebuild switch` (atomic, rollback-able) |

## Common Commands

```bash
# Service management
systemctl status prism-django
systemctl restart prism-django
journalctl -u prism-django -f

# Django management commands
sudo -u prism prism-manage createsuperuser
sudo -u prism prism-manage create_test_users
sudo -u prism prism-manage shell

# Check collected static files
ls -la /var/lib/prism-django/staticfiles/

# Check PostgreSQL
sudo -u postgres psql -d prism -c '\dt'
```

## Troubleshooting Quick Reference

**Static files not loading:**
```bash
# Check if collectstatic ran
ls -la /var/lib/prism-django/staticfiles/
# Should see: admin/, css/, sounds/, staticfiles.json

# Check STATIC_ROOT environment
systemctl show prism-django | grep STATIC_ROOT
# Should output: Environment=STATIC_ROOT=/var/lib/prism-django/staticfiles

# Manually run collectstatic
sudo -u prism STATIC_ROOT=/var/lib/prism-django/staticfiles prism-collectstatic
```

**Database connection errors:**
```bash
# Check PostgreSQL is running
systemctl status postgresql

# Check database exists
sudo -u postgres psql -l | grep prism

# Test connection
sudo -u prism psql -h localhost -U prism -d prism -c 'SELECT 1;'
```

**Permission errors:**
```bash
# Fix state directory ownership
sudo chown -R prism:prism /var/lib/prism-django
sudo chmod 755 /var/lib/prism-django/staticfiles
```

## Why This Approach is Better Than Full Module

**Simpler:**
- Single file (`prism-django.nix`) vs. full module with many options
- Easy to read and understand
- Direct control over environment variables

**Flexible:**
- Easy to customize for your specific needs
- No abstraction layers hiding what's happening
- Can directly edit systemd service config

**Transparent:**
- See exactly what commands run (migrations, collectstatic, gunicorn)
- Environment variables clearly visible
- No magic happening behind the scenes

**Standard NixOS patterns:**
- Uses sops-nix for secrets (like other services on midship)
- Uses systemd hardening (like workshop-watcher, overseer, etc.)
- Uses tmpfiles.d for directory creation

## What You DON'T Need

You do NOT need:
- ❌ The full NixOS module (`modules/prism-django.nix`)
- ❌ Complex options system
- ❌ Automated nginx configuration (can add manually if needed)
- ❌ Database initialization automation (PostgreSQL service handles this)
- ❌ Secret generation scripts

This simplified service does everything you need!
