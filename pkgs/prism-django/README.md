# Prism Django - NixOS Package

NixOS package and module for the Prism Django application - a data aggregation backend for EVE Online applications.

## Package Structure

- **`pkgs/prism-django/default.nix`**: Package derivation
- **`modules/prism-django.nix`**: NixOS service module
- **`examples/prism-django-config.nix`**: Example configurations

## Quick Start

### 1. Add to your flake.nix

If using flakes, ensure the package is available in your outputs:

```nix
# In your flake.nix
{
  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        ./modules/prism-django.nix
        {
          services.prism-django.enable = true;
          # ... other configuration
        }
      ];
    };
  };
}
```

### 2. Basic Configuration

Add to your host's `configuration.nix`:

```nix
services.prism-django = {
  enable = true;
  
  # Generate with: python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
  secretKey = "your-secret-key-here";
  
  allowedHosts = [ "localhost" "127.0.0.1" ];
  
  # SQLite database (default)
  databaseUrl = "sqlite:////var/lib/prism-django/db.sqlite3";
};
```

### 3. Rebuild and start

```bash
sudo nixos-rebuild switch
sudo systemctl status prism-django
```

The application will be available at `http://127.0.0.1:8000`

## Available Commands

The package provides several wrapper commands:

- **`prism-manage`**: Django management commands
  ```bash
  prism-manage createsuperuser
  prism-manage create_test_users
  prism-manage migrate
  prism-manage collectstatic
  ```

- **`prism-gunicorn`**: Production server (used by systemd service)
  
- **`prism-runserver`**: Development server (manual testing)
  ```bash
  prism-runserver 0.0.0.0:8000
  ```

- **`prism-migrate`**: Run migrations (used by systemd preStart)
  
- **`prism-collectstatic`**: Collect static files (used by systemd preStart)

## Configuration Options

### Core Settings

- **`enable`**: Enable the service (default: `false`)
- **`package`**: Package to use (default: `pkgs.prism-django`)
- **`user`**: Service user (default: `"prism"`)
- **`group`**: Service group (default: `"prism"`)
- **`stateDir`**: State directory (default: `"/var/lib/prism-django"`)

### Server Settings

- **`listenAddress`**: Bind address (default: `"127.0.0.1"`)
- **`port`**: Bind port (default: `8000`)
- **`workers`**: Gunicorn workers (default: `4`)

### Django Settings

- **`secretKey`**: Django SECRET_KEY (required)
- **`secretKeyFile`**: Path to file containing SECRET_KEY (optional, takes precedence)
- **`debug`**: Debug mode (default: `false`, **never enable in production**)
- **`allowedHosts`**: List of allowed hosts
- **`databaseUrl`**: Database connection URL
- **`requireEmailVerification`**: Require email verification (default: `false`)

### Email Settings

- **`email.backend`**: Email backend (default: console)
- **`email.host`**: SMTP host
- **`email.port`**: SMTP port
- **`email.useTls`**: Use TLS (default: `true`)
- **`email.hostUser`**: SMTP username
- **`email.hostPasswordFile`**: Path to file containing SMTP password
- **`email.defaultFrom`**: Default from address

### Nginx Settings

- **`nginx.enable`**: Enable nginx reverse proxy (default: `false`)
- **`nginx.hostName`**: Virtual host name
- **`nginx.enableACME`**: Enable Let's Encrypt (default: `false`)
- **`nginx.forceSSL`**: Force SSL (default: `false`)

## Production Deployment Examples

### PostgreSQL + Nginx + ACME

```nix
services.prism-django = {
  enable = true;
  
  secretKeyFile = config.sops.secrets."prism/secret-key".path;
  allowedHosts = [ "prism.example.com" ];
  
  databaseUrl = "postgresql://prism:password@localhost/prism";
  
  email = {
    backend = "django.core.mail.backends.smtp.EmailBackend";
    host = "smtp.gmail.com";
    port = 587;
    hostUser = "your-email@gmail.com";
    hostPasswordFile = config.sops.secrets."prism/email-password".path;
  };
  
  workers = 9;  # (2 x 4 cores) + 1
  
  nginx = {
    enable = true;
    hostName = "prism.example.com";
    enableACME = true;
    forceSSL = true;
  };
};

services.postgresql = {
  enable = true;
  ensureDatabases = [ "prism" ];
  ensureUsers = [{
    name = "prism";
    ensureDBOwnership = true;
  }];
};

networking.firewall.allowedTCPPorts = [ 80 443 ];
```

### Using sops-nix for Secrets

```nix
sops.secrets = {
  "prism/secret-key" = {
    sopsFile = ./secrets.yaml;
    owner = config.services.prism-django.user;
  };
  "prism/email-password" = {
    sopsFile = ./secrets.yaml;
    owner = config.services.prism-django.user;
  };
};

services.prism-django = {
  enable = true;
  secretKeyFile = config.sops.secrets."prism/secret-key".path;
  email.hostPasswordFile = config.sops.secrets."prism/email-password".path;
};
```

## Development Workflow

### Running Migrations

Migrations run automatically on service start, but you can run them manually:

```bash
sudo -u prism prism-manage migrate
```

### Creating Superuser

```bash
sudo -u prism prism-manage createsuperuser
```

### Creating Test Users

```bash
sudo -u prism prism-manage create_test_users
```

This creates:
- admin/admin123 (Superuser)
- adminuser/admin123 (Admin)
- moderator/mod123 (Moderator)
- user/user123 (User)

### Accessing Django Shell

```bash
sudo -u prism prism-manage shell
```

### Viewing Logs

```bash
sudo journalctl -u prism-django -f
```

## Troubleshooting

### Service won't start

Check logs:
```bash
sudo journalctl -u prism-django -xe
```

### Database connection issues

Verify DATABASE_URL and PostgreSQL service:
```bash
sudo systemctl status postgresql
sudo -u postgres psql -l
```

### Static files not loading

Collectstatic runs automatically on service start, but you can run manually:
```bash
sudo -u prism prism-collectstatic
```

### Permission errors

Ensure state directory permissions:
```bash
sudo chown -R prism:prism /var/lib/prism-django
```

## Upgrading

To upgrade to a new version:

1. Update the package (if pinned to a specific rev):
   ```nix
   # In pkgs/prism-django/default.nix
   rev = "new-commit-hash";
   ```

2. Rebuild:
   ```bash
   sudo nixos-rebuild switch
   ```

3. The service will automatically run migrations and collect static files on restart.

## File Locations

- **Application**: `/nix/store/*/share/prism-django/`
- **Database** (SQLite): `/var/lib/prism-django/db.sqlite3`
- **Static files**: `/var/lib/prism-django/staticfiles/`
- **Media files**: `/var/lib/prism-django/media/`
- **Logs**: `journalctl -u prism-django`

## Security Considerations

1. **Never enable `debug = true` in production**
2. **Use `secretKeyFile` with sops-nix or agenix for secret management**
3. **Use strong, random SECRET_KEY (50+ characters)**
4. **Configure firewall appropriately**
5. **Use HTTPS in production (nginx.enableACME = true)**
6. **Regularly update the package to get security patches**

## Related Documentation

- [Prism Django GitHub](https://github.com/h0lylag/prism-django)
- [Django Documentation](https://docs.djangoproject.com/)
- [Gunicorn Documentation](https://docs.gunicorn.org/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
