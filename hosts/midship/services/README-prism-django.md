# Prism Django on NixOS - Simplified Service Configuration

## Overview

This simplified systemd service configuration runs the Prism Django application on the midship host using Gunicorn, PostgreSQL, and WhiteNoise for static file serving.

## How It Works on NixOS

### Read-Only Application Directory

The Prism Django application is installed in the **read-only Nix store** at a path like:
```
/nix/store/xxxxx-prism-django/share/prism-django/
```

This means:
- ✅ You **CAN** read application code, templates, and bundled static files
- ❌ You **CANNOT** write database files, static files, or media uploads to the application directory
- ✅ Solution: Use a **writable state directory** at `/var/lib/prism-django/`

### How Static Files Work

**1. Development (source directory):**
- Static files live in `prism-django/static/` (CSS, JS, sounds)
- Django serves them directly via `django.contrib.staticfiles`

**2. Production (NixOS):**
- Source static files are copied to Nix store (read-only)
- `collectstatic` command gathers all static files and copies them to `STATIC_ROOT`
- `STATIC_ROOT` points to **writable state directory**: `/var/lib/prism-django/staticfiles/`
- WhiteNoise serves static files from this writable location
- Static files are **compressed and hashed** by WhiteNoise for performance

**Why this works:**
```nix
# In prism-django.nix:
Environment = [
  "STATIC_ROOT=/var/lib/prism-django/staticfiles"  # Writable location!
];

preStart = ''
  ${prism-django}/bin/prism-collectstatic --noinput  # Copies to STATIC_ROOT
'';
```

### How Database Migrations Work

**Migrations write to PostgreSQL database**, not to the filesystem:
- ✅ Migration files are read from the read-only Nix store
- ✅ Django connects to PostgreSQL at `localhost:5432`
- ✅ Migration state is stored in the `django_migrations` table in PostgreSQL
- ✅ No filesystem writes needed (except PostgreSQL's own data directory)

**Why this works:**
```nix
preStart = ''
  ${prism-django}/bin/prism-migrate  # Reads migrations from Nix store, writes to PostgreSQL
'';
```

### Wrapper Scripts

The package provides 5 wrapper commands that "just work" in NixOS:

1. **`prism-manage`** - Django management commands (e.g., `prism-manage createsuperuser`)
2. **`prism-gunicorn`** - Production WSGI server (main service)
3. **`prism-runserver`** - Development server (testing only)
4. **`prism-migrate`** - Run database migrations
5. **`prism-collectstatic`** - Collect static files to STATIC_ROOT

These wrappers:
- Set correct `PYTHONPATH` to find Django and dependencies
- Set working directory to application root in Nix store
- Respect environment variables from systemd service

## Setup Instructions

### 1. Create Secrets File

Create `/home/chris/.nixos-config/secrets/prism-django.env`:
```bash
# Required
SECRET_KEY=generate-a-long-random-secret-key-here-use-pwgen-or-similar
POSTGRES_PASSWORD=your-secure-postgres-password

# Optional (if using email)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=true
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noreply@prism.midship.local
```

**Encrypt with sops:**
```bash
cd /home/chris/.nixos-config
sops secrets/prism-django.env
```

### 2. Import Service in Host Configuration

Add to `/home/chris/.nixos-config/hosts/midship/default.nix`:
```nix
imports = [
  ./hardware-configuration.nix
  ./services/prism-django.nix  # Add this line
  # ... other imports ...
];
```

### 3. Ensure PostgreSQL is Running

The service requires PostgreSQL. Check if it's already configured in `midship/services/postgresql.nix` or add:
```nix
services.postgresql = {
  enable = true;
  ensureDatabases = [ "prism" ];
  ensureUsers = [
    {
      name = "prism";
      ensureDBOwnership = true;
    }
  ];
};
```

### 4. Rebuild System

```bash
cd /home/chris/.nixos-config
sudo nixos-rebuild switch --flake .#midship
```

### 5. Create Django Superuser

```bash
# SSH to midship
ssh midship

# Run management command as prism user
sudo -u prism prism-manage createsuperuser
```

### 6. Access Application

- **Direct access**: http://midship.local:8000/
- **Via nginx**: Uncomment nginx config in `prism-django.nix`, rebuild, access at http://prism.midship.local/

## Service Management

```bash
# Check service status
systemctl status prism-django

# View logs
journalctl -u prism-django -f

# Restart service (runs migrations and collectstatic automatically)
systemctl restart prism-django

# Run Django management commands
sudo -u prism prism-manage <command>
```

## Troubleshooting

### Static Files Not Loading
```bash
# Check if collectstatic ran successfully
ls -la /var/lib/prism-django/staticfiles/

# Manually collect static files
sudo -u prism prism-collectstatic --noinput

# Check environment variable
systemctl show prism-django | grep STATIC_ROOT
```

### Migration Issues
```bash
# Check PostgreSQL connection
sudo -u prism psql -h localhost -U prism -d prism -c '\dt'

# Manually run migrations
sudo -u prism prism-migrate
```

### Permission Errors
```bash
# Fix state directory ownership
sudo chown -R prism:prism /var/lib/prism-django
sudo chmod 750 /var/lib/prism-django
sudo chmod 755 /var/lib/prism-django/staticfiles  # Needs to be readable by nginx
```

## Why This Approach?

**Advantages of simplified systemd service:**
- ✅ **Simple**: Just a systemd service, no complex module options
- ✅ **Flexible**: Easy to customize environment variables
- ✅ **Transparent**: Clear what's happening (migrations, collectstatic, gunicorn)
- ✅ **Standard**: Uses NixOS patterns (sops-nix, systemd hardening, tmpfiles.d)

**When to use full module (not recommended here):**
- ❌ Multi-tenant hosting (multiple Django apps on same host)
- ❌ Complex configuration with many conditional options
- ❌ Automated nginx/SSL/database setup across multiple hosts
- ❌ You want declarative configuration of all Django settings

For a single Django app on a single host, **this simplified service is better**.

## Architecture Recap

```
┌─────────────────────────────────────────────────────┐
│ /nix/store/xxxxx-prism-django/                     │
│ └── share/prism-django/  (READ-ONLY)               │
│     ├── manage.py                                   │
│     ├── prism/ (settings.py, urls.py)              │
│     ├── accounts/, lighthouse/, notifications/      │
│     ├── templates/                                  │
│     └── static/ (source CSS/JS - not served!)      │
└─────────────────────────────────────────────────────┘
                      ↓
        ┌─────────────────────────┐
        │ prism-collectstatic     │ ← Runs in preStart
        └─────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ /var/lib/prism-django/  (READ-WRITE)               │
│ ├── staticfiles/ (collected & compressed)          │ ← STATIC_ROOT
│ │   ├── admin/                                      │
│ │   ├── css/                                        │
│ │   ├── sounds/                                     │
│ │   └── staticfiles.json (manifest)                │
│ └── media/ (user uploads)                          │ ← MEDIA_ROOT
└─────────────────────────────────────────────────────┘
                      ↑
        ┌─────────────────────────┐
        │ WhiteNoise middleware   │ ← Serves static files
        └─────────────────────────┘
                      ↑
        ┌─────────────────────────┐
        │ Gunicorn (4 workers)    │ ← Main service
        │ Binds to 127.0.0.1:8000 │
        └─────────────────────────┘
                      ↑
        ┌─────────────────────────┐
        │ Nginx (optional)        │ ← Reverse proxy
        │ prism.midship.local     │
        └─────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PostgreSQL                                          │
│ ├── Database: prism                                 │
│ ├── User: prism                                     │
│ └── django_migrations table (migration state)      │ ← prism-migrate writes here
└─────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Application code**: Read-only in `/nix/store/xxxxx-prism-django/`
2. **Static files**: Collected to writable `/var/lib/prism-django/staticfiles/`
3. **Database**: PostgreSQL at `localhost:5432`, migrations write to DB not filesystem
4. **Secrets**: sops-nix manages `SECRET_KEY` and `POSTGRES_PASSWORD`
5. **Service lifecycle**: preStart runs migrations + collectstatic, then starts gunicorn
6. **Wrapper commands**: Use `prism-manage`, `prism-migrate`, etc. for management tasks
