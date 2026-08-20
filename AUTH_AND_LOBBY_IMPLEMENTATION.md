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
- `main.tscn`: populated the existing empty Login and Register page placeholders.
- `ui/time_trial_start_screen.gd`: provider routing, registration state, local display preference, and post-login lobby route.
