# Features

Simple configuration snippets that enable specific features or functionality.

## What Goes Here?

**Features** are simple NixOS configuration fragments that:
- ✅ Enable a single feature or tool
- ✅ Set sensible defaults
- ✅ Do NOT have `options` blocks (no configuration interface)
- ✅ Are "batteries included" - work out of the box

If you need to configure something, it should be a **module** instead (in `../modules/`).

## Available Features

### `podman.nix`
Enables Podman container runtime with:
- Docker compatibility layer
- Container-to-container DNS resolution
- Automatic pruning (weekly)
- podman-compose included

**Use when**: You need container support on a system

### `star-citizen.nix`
Enables Star Citizen game via nix-citizen:
- Sets up Cachix for nix-gaming and nix-citizen
- Enables the Star Citizen launcher
- Configures MangoHUD and Wayland display settings

**Use when**: Gaming workstation that runs Star Citizen

## Usage

Import features directly in your host or profile:

```nix
# In a host config
{
  imports = [
    ../../features/podman.nix
    ../../features/star-citizen.nix
  ];
}

# In a profile
{
  imports = [
    ../features/podman.nix
  ];
}
```

## Features vs Modules vs Profiles

### Features (this directory)
- **Purpose**: Enable a specific tool/feature
- **Complexity**: Simple, no options
- **Example**: `podman.nix` - just enables podman

### Modules (`../modules/`)
- **Purpose**: Configurable services
- **Complexity**: Has `options` and `config` blocks
- **Example**: `dayz-server.nix` - full configuration interface

### Profiles (`../profiles/`)
- **Purpose**: Complete machine roles
- **Complexity**: Bundles features + modules + settings
- **Example**: `workstation.nix` - everything for a GUI machine

## Adding New Features

When adding a new feature, ask:
1. **Is it simple?** - No configuration needed?
2. **Is it focused?** - Does one thing well?
3. **Is it reusable?** - Multiple machines might use it?

If yes to all three, it's a feature! Otherwise:
- Needs configuration? → Make it a **module** with options
- Bundles many things? → Make it a **profile**
