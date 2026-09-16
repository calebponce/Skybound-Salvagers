# Skybound Salvagers

A Roblox vertical slice: claim a sky harbor, collect salvage from a floating island, upgrade your harbor, and join recurring storm events.

## Run it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/).
2. From this folder, run `rojo serve`.
3. Open a new **Baseplate** in Roblox Studio, install the Rojo plugin, then connect to `default.project.json`.
4. Press **Play**. Use Studio's **Server & Clients** mode to test multiple players.

## Regression checks

Run `npm ci --ignore-scripts` once, then `npm test`. These checks execute the actual
save decoder, crew objective logic and player-interaction helper with mocked
Roblox dependencies. They require Node.js, not Xcode, and never access player data.
Run `npm run build` to regenerate the local Roblox place with Rojo.

These checks do not replace Studio testing, Luau syntax/type checks, DataStore
integration tests or multiplayer/device playtests. See [DEVELOPMENT.md](DEVELOPMENT.md)
for the active audit backlog and remaining verification work.

## Included features

- Six personal sky-harbor plots assigned automatically.
- Floating salvage crates worth Salvage currency.
- A harbor upgrade terminal.
- Timed storm events with high-value storm cores.
- DataStore-backed progression with a session-only Studio fallback.
- A mobile-friendly HUD and tutorial messages.

## Next build targets

1. Original art, audio, and animations.
2. A short expedition with hazards and creature rescue.
3. Inventory, ship customization, and co-op objectives.
4. Playtests and cosmetic-only monetization.
