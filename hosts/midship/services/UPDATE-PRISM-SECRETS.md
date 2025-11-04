# Update Prism Secrets File

## Current State

Your secrets file at `/home/chris/.nixos-config/secrets/prism.env` currently has:
- ✅ `POSTGRES_PASSWORD` (correct)
- ❌ `POSTGRES_USERNAME` (needs to be renamed to `POSTGRES_USER`)
- ❌ `EMAIL_PASSWORD` (needs to be renamed to `EMAIL_HOST_PASSWORD`)
- ❌ Missing `SECRET_KEY` (required for Django)
- ❌ Missing `POSTGRES_USER` (currently named wrong)
- ❌ Missing `EMAIL_HOST_USER` (optional, for email sending)

## Required Changes

### Step 1: Generate a SECRET_KEY

Django requires a strong SECRET_KEY. Generate one:

```bash
# Option 1: Using Python
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Option 2: Using OpenSSL
openssl rand -base64 50

# Option 3: Using pwgen
pwgen -s 50 1
```

Copy the output - you'll need it in the next step.

### Step 2: Edit the secrets file with sops

```bash
cd /home/chris/.nixos-config
sops secrets/prism.env
```

### Step 3: Update the file to have these exact variable names

**Before (current):**
```env
POSTGRES_USERNAME=prism
POSTGRES_PASSWORD=your-encrypted-password
EMAIL_PASSWORD=your-encrypted-email-password
```

**After (correct):**
```env
# Django secret key (REQUIRED)
SECRET_KEY=your-generated-secret-key-from-step-1

# PostgreSQL credentials (REQUIRED)
POSTGRES_USER=prism
POSTGRES_PASSWORD=your-encrypted-password

# Email credentials (OPTIONAL - for sending emails via SMTP)
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-encrypted-email-password
```

### Step 4: Save and exit sops

Press `Ctrl+O` to save, then `Ctrl+X` to exit (if using nano), or `:wq` (if using vim).

## Variable Name Mapping

| Old Name (Wrong) | New Name (Correct) | Required? | Used For |
|------------------|-------------------|-----------|----------|
| N/A | `SECRET_KEY` | ✅ Required | Django cryptographic signing |
| `POSTGRES_USERNAME` | `POSTGRES_USER` | ✅ Required | PostgreSQL username |
| `POSTGRES_PASSWORD` | `POSTGRES_PASSWORD` | ✅ Required | PostgreSQL password |
| N/A | `EMAIL_HOST_USER` | ⚠️ Optional | Email sending (SMTP username) |
| `EMAIL_PASSWORD` | `EMAIL_HOST_PASSWORD` | ⚠️ Optional | Email sending (SMTP password) |

## Why These Names?

Django's `python-decouple` library looks for these specific environment variable names in `settings.py`:

```python
# settings.py expects:
SECRET_KEY = config('SECRET_KEY', default='...')                    # Crypto key
POSTGRES_USER = config('POSTGRES_USER', default='prism')           # DB username
POSTGRES_PASSWORD = config('POSTGRES_PASSWORD')                    # DB password
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')            # Email username
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')    # Email password
```

## After Updating Secrets

Once you've updated the secrets file with the correct variable names:

```bash
cd /home/chris/.nixos-config

# Build and switch to the new configuration
sudo nixos-rebuild switch --flake .#midship

# Check if the service started successfully
systemctl status prism-django

# View logs
journalctl -u prism-django -f
```

## Troubleshooting

### "SECRET_KEY not found" error
```bash
# Check if the secret is properly decrypted
sudo cat /run/secrets/prism-env | grep SECRET_KEY

# If empty, edit secrets file again
sops secrets/prism.env
```

### Database connection errors
```bash
# Check PostgreSQL user exists
sudo -u postgres psql -c '\du' | grep prism

# Create user if needed
sudo -u postgres createuser prism
sudo -u postgres createdb prism -O prism
```

### Email errors (if using SMTP)
- Email is optional - if you don't need email, leave `EMAIL_HOST_USER` and `EMAIL_HOST_PASSWORD` empty
- The service will still work without email configured
- To disable email entirely, the service already sets a fallback to console backend

## Quick Reference

**Minimal working secrets file:**
```env
SECRET_KEY=django-insecure-your-50-character-random-string-here
POSTGRES_USER=prism
POSTGRES_PASSWORD=your-secure-password
```

**Full secrets file (with email):**
```env
SECRET_KEY=django-insecure-your-50-character-random-string-here
POSTGRES_USER=prism
POSTGRES_PASSWORD=your-secure-password
EMAIL_HOST_USER=noreply@yourdomain.com
EMAIL_HOST_PASSWORD=your-smtp-password
```
