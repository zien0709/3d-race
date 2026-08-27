# Login Interface Decoupling Changes

## Overview
Complete decoupling of the login/register page from direct NetworkManager/PlayerStorage dependencies. All auth logic now resides in `/root/AuthManager` Autoload.

## Changes Made

### 1. New: `scripts/auth_manager.gd` (Autoload `/root/AuthManager`)
Handles **all** EOS authentication and profile management:
- **Signals emitted**:
  - `login_succeeded(display_name, product_user_id)` - when login completes
  - `login_failed(message)` - when login fails
  - `eos_initialized(success, message)` - when EOS init completes
  - `logout` - when player logs out
  - `environment_ready`, `weather_changed`, `wind_changed` - env sync
- **Public API**:
  - `init_eos()` - Initialize EOS with config from `res://eos_config.cfg`
  - `login(provider)` - Login with specified provider (epic, discord, anonymous)
  - `logout()` - Log out and emit signal
  - `save_profile(profile)` / `load_profile()` / `has_profile()` - PlayerDataStorage
  - `sync_environment_from_network(data)` - Sync weather/time/wind from network
- **Helper methods** (lazy init):
  - `set_network_manager(node_path)`, `set_player_storage(node_path)`, `set_environment_manager(node_path)`
  - `is_logged_in()`, `display_name()`, `product_user_id()`, `is_eos_ready()`

### 2. Updated: `project.godot`
Added AuthManager to autoload section:
```
[autoload]
NetworkManager="*res://network/network_manager.gd"
PlayerStorage="*res://network/player_storage.gd"
LobbyManager="*res://network/lobby_manager.gd"
AuthManager="*res://scripts/auth_manager.gd"   ← **ADDED**
...
```

### 3. Refactored: `ui/time_trial_start_screen.gd`
**Before (coupled)**:
- Direct calls to `NetworkManager.init_eos()`, `NetworkManager.login()`
- Direct calls to `PlayerStorage.load_profile()`, `save_profile()`
- Direct `get_tree().change_scene_to_file()` calls
- `@onready` references mixed with business logic

**After (decoupled)**:
- Connects to `AuthManager` signals in `_ready()`:
  ```gdscript
  var auth = get_node_or_null("/root/AuthManager")
  if auth != null:
      auth.login_succeeded.connect(_on_auth_succeeded)
      auth.login_failed.connect(_on_auth_failed)
      auth.eos_initialized.connect(_on_eos_initialized)
  ```
- `_on_auth_succeeded()` handles both login and registration flows via signal
- `_on_create_account_pressed()` saves profile via `AuthManager.save_profile()`, then changes scene
- `_restore_display_name()` uses `AuthManager.load_profile()` + local fallback
- All `@onready` references are **pure UI elements**, no business logic
- `_begin_login()` delegates to `AuthManager.init_eos()` / `AuthManager.login()`
- `_try_auto_login()` / `_do_auto_login()` use AuthManager persistent login

### 4. Fixed GDScript Syntax Issues
- **Ternary operator**: Changed from `condition ? value : default` (invalid GDScript) to `value if condition else default` (Godot correct syntax)
- **Variable shadowing**: Fixed `var :=` assignments that redeclared variables
- **Function name clash**: Renamed `logout()` to `logout_user()` in auth_manager.gd to avoid conflicting with `signal logout`

## Signal Flow

```
Login/Register UI
    ↓ (connects to signals)
AuthManager (/root/AuthManager)
    ↓ (emits signals)
time_trial_start_screen.gd (UI updates only)
    ↓ (emits start_requested)
Parent scene / Lobby system
```

## Key Benefits

1. **Single source of auth logic** - All EOS init/login/profile management in one place
2. **UI agnostic** - UI code doesn't need to know about NetworkPlayerStorage paths
3. **Testable** - AuthManager can be tested independently of scene state
4. **Replaceable** - Swap auth implementation without touching UI code
5. **Persistent login support** - `try_persistent_login()`, `login_persistent_auth_async` handled centrally
6. **Environment sync** - Weather/time/wind from network automatically propagated via signals

## Files Modified
- `scripts/auth_manager.gd` **NEW** - 433 lines, complete auth system
- `project.godot` - Added AuthManager autoload entry
- `ui/time_trial_start_screen.gd` - Refactored to UI-only, ~260 lines
- `scripts/auth_manager.gd` - Fixed: `logout` → `logout_user` to resolve signal/function clash