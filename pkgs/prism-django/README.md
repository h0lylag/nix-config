# Prism Django – NixOS Packaging & Service Guide

This repository contains everything needed to package and run the Prism Django
application on NixOS. The setup favours a simple systemd service definition
instead of a full module, while still providing a reproducible package that
fetches the application directly from GitHub and bundles all Python
dependencies.

## Key Files

- `pkgs/prism-django/default.nix` – build of the Prism Django sources, Python
  environment, and wrapper scripts (`prism-manage`, `prism-gunicorn`,
  `prism-migrate`, etc.).
- `hosts/midship/services/prism-django.nix` – declarative service definition
  used on the `midship` host. Handles migrations, static collection, secrets,
  and systemd hardening.

## What the Package Provides

- Code is pulled from `git@github.com:h0lylag/prism-django.git` (branch `main`).
- Python 3.13 environment with Django 5, WhiteNoise, Gunicorn, crispy-forms,
  crispy-bootstrap5 (built from PyPI), psycopg2, Pillow, DRF, etc.
- Wrapper binaries placed in `$out/bin`:
  - `prism-manage` – general management commands
  - `prism-gunicorn` – production WSGI server
  - `prism-runserver` – dev server
  - `prism-migrate` – `manage.py migrate --noinput`
  - `prism-collectstatic` – `manage.py collectstatic --noinput`

These wrappers automatically set `PATH`, `PYTHONPATH`, and working directory so
they can be used directly from the systemd service or on the host (via
`sudo -u prism prism-manage …`).

## Service Overview (hosts/midship/services/prism-django.nix)

- Creates `prism` system user and state directories under `/var/lib/prism-django`.
- Uses `sops.secrets.prism-env` for sensitive configuration (owned by `prism`).
- `preStart` runs migrations and `collectstatic`, ensuring static assets land in
  `/var/lib/prism-django/staticfiles/`.
- Gunicorn runs under systemd with `Type=notify`, binding `127.0.0.1:8000`.
- WhiteNoise serves static files from the writable state directory.
- Systemd hardening restricts filesystem access to the state directory.

## Deploying on Midship

1. **Prepare secrets** (`/home/chris/.nixos-config/secrets/prism.env`):

   ```env
   SECRET_KEY=<generate with python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())">
   POSTGRES_USER=prism
   POSTGRES_PASSWORD=<postgres password>
   EMAIL_HOST_USER=noreply@yourdomain.com        # optional, SMTP
   EMAIL_HOST_PASSWORD=<smtp password>           # optional, SMTP
   ```

   Encrypt with `sops secrets/prism.env`.

2. **Import the service** in `hosts/midship/default.nix`:

   ```nix
   imports = [
     ./services/prism-django.nix
     # …existing imports…
   ];
   ```

3. **Ensure PostgreSQL** is available (`services/postgresql.nix` already sets up
   database + user on midship).

4. **Build and switch**:

   ```bash
   # On relic (development machine)
   nix build .#nixosConfigurations.midship.config.system.build.toplevel --no-link --impure

   # Deploy on midship
   ssh midship
   cd ~/.nixos-config
   git pull
   sudo nixos-rebuild switch --flake .#midship
   ```

5. **Create a Django superuser**:

   ```bash
   sudo -u prism prism-manage createsuperuser
   ```

6. **Access the app**: http://midship.local:8000/ (add nginx reverse proxy if
   needed; snippet is commented inside the service file).

## Secrets Recap

| Variable             | Required | Description                                   |
|----------------------|----------|-----------------------------------------------|
| `SECRET_KEY`         | ✅        | Django cryptographic key (50+ random chars)    |
| `POSTGRES_USER`      | ✅        | PostgreSQL username                            |
| `POSTGRES_PASSWORD`  | ✅        | PostgreSQL password                            |
| `EMAIL_HOST_USER`    | ⚠️       | SMTP username (if sending email)               |
| `EMAIL_HOST_PASSWORD`| ⚠️       | SMTP password (if sending email)               |

## Static Files & Migrations

- `prism-collectstatic` writes assets to `/var/lib/prism-django/staticfiles/`.  
  WhiteNoise serves from this directory at runtime.
- `prism-migrate` applies migrations directly against PostgreSQL.
- Both commands run automatically in `preStart`, so every service restart keeps
  the database schema and static bundle current.

## Service Management

```bash
systemctl status prism-django
journalctl -u prism-django -f
systemctl restart prism-django

# Run management commands
sudo -u prism prism-manage shell
sudo -u prism prism-manage create_test_users
```

## Troubleshooting Quick Reference

- **Static files missing**: `ls -la /var/lib/prism-django/staticfiles/` and
  `sudo -u prism prism-collectstatic`.
- **Database issues**: ensure PostgreSQL is running and credentials match
  `sops` secret. Test with `sudo -u prism psql -h localhost -U prism -d prism`.
- **Permission errors**: `sudo chown -R prism:prism /var/lib/prism-django` and
  ensure `staticfiles/` is at least mode `755` if nginx needs to read it.

## Notes on Reproducibility

- `fetchGit` tracks the `main` branch. For fully reproducible builds, pin a
  specific commit by uncommenting the `rev = "…"` line.
- `crispy-bootstrap5` is sourced from the official PyPI tarball with a locked
  SHA256 hash.

With this structure, the Prism backend can be rebuilt, deployed, and managed on
NixOS using standard workflows while keeping the service definition easy to
understand and modify.
