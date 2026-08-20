# Authentication And Lobby Implementation

## Stage 1: Social authentication UI

### Goal
- Keep the existing quick-play flow intact.
- Do not add email/password authentication or a project-owned credential database.
- Let the player authenticate through an external provider, then enter `res://ui/lobby.tscn`.

### Implemented UI
- `LoginPage` contains full-width Epic Games, Discord, and disabled Google provider buttons.
- `RegisterPage` uses the same provider-first flow, then asks for a public display name and Terms acceptance.
- The Google controls remain intentionally disabled until a Google OAuth/EOS integration is configured.

### Runtime flow
1. Login buttons initialize EOS when necessary and launch the selected provider flow.
2. A normal successful login switches to `res://ui/lobby.tscn`.
3. A registration successful login stays on the registration page until a display name and Terms acceptance are supplied.
4. Registration writes only local presentation preferences to `user://player_profile.cfg`; credentials remain with Epic/Discord.

### Deliberate limitation
- `user://player_profile.cfg` is local-only. It does not publish an account profile, leaderboard record, or Terms consent to a server.
- A public leaderboard will need a backend that stores the EOS Product User ID, chosen display name, consent record, and verified race result. This implementation does not claim otherwise.

### Files changed
- `ui/time_trial_start_screen.tscn`: populated the existing empty Login and Register page placeholders.
- `ui/time_trial_start_screen.gd`: provider routing, registration state, local display preference, and post-login lobby route.

## Stage 2: Post-login lobby

### Layout decisions
- The login page uses a vertical stack of full-width provider buttons (Epic, Discord, disabled Google) - the "guided" layout.
- The register page puts the three providers in a compact horizontal row of short buttons (Epic / Discord / Google), then asks for a public display name, Terms acceptance, and shows the create-account button.
- Google stays disabled everywhere until a real Google OAuth/EOS integration exists; the UI never pretends it is available.

### Login → lobby
- A successful login from the login tab switches to `res://ui/lobby.tscn`.
- `res://ui/lobby.tscn` is a scripted root: `ui/lobby_ui.gd` builds the room card, player card, car slots, chat and garage at runtime, and already reads `NetworkManager.display_name` / `product_user_id` for the player card, so a freshly authenticated player is shown correctly without further work.

### Verification status
- `ui/time_trial_start_screen.gd` and `.tscn` pass Godot script/scene parsing (verified via editor diagnostics).
- Runtime launch is currently blocked by pre-existing parse errors in `res://race_manager.gd` (undeclared leaderboard/hud variables) which belong to parallel work and are intentionally not touched by this change. Once that file compiles, the login flow can be exercised end to end.
