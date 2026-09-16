# Development backlog

Keep this record current after each cohesive change. Preserve existing player data and user edits. Do not publish to Roblox.

## Repository workflow

GitHub repository: `calebponce/Skybound-Salvagers`. Continue the audit/reliability milestone on `caleb/game-audit`; do not create a branch for each scheduled run. The user authorized cohesive, useful development-branch pushes and milestone merges to `main` when ready. Compare current remote state before uploads, preserve unrelated changes and never force-push. Keep gameplay changes off `main` until relevant Studio checks are completed. Source tests and successful builds alone do not establish release readiness.

## Save safety — in progress

- Implemented: successful reads required before saving; live load failures refuse entry; Studio failure sessions cannot save; departures during reads cannot create orphaned player state.
- Studio session-only fallback now displays a persistent non-saving notice beneath the HUD; the server sets it only after loading resolves, not while a read is still pending.
- Implemented: isolated ProgressData decoder rejects malformed known fields, non-finite/negative/fractional counters and unknown characters; missing legacy fields retain defaults; numeric strings remain compatible.
- Tests: `tests/progress-data.lua` exercises the real decoder without Roblox services. This does not test DataStore networking.
- Verified September 16: decoder tests passed using the Fengari Lua runtime; Rojo rebuilt `SkyboundSalvagers.rbxl` successfully. Roblox service integration and Studio playtesting remain pending.
- Still required: Studio mocked-service integration tests for read failure, disconnect during read, autosave and shutdown; live save concurrency/session ownership review. Existing SetAsync persistence has no session lock and is not production-hardened.

## Next priorities

1. Guardian encounter implemented: shared 0.9-second red-sphere wind-up, range recheck at impact, two-second recovery. Defeating the guardian during wind-up cancels the hit. Pending Studio checks: escape timing, visual readability, multiple players, death/respawn, mobile controls and difficulty balance.
2. Rook now interrupts a surviving guardian's charged attack by striking during wind-up, with an eight-second per-guardian interrupt cooldown. The warning clears and the eye turns aqua; cancelled attacks still enter recovery. Character/guide descriptions updated. Pending Studio timing and multiplayer tests; Luma/Briggs active support abilities remain unfinished.
3. Shared crew objectives now freeze at first recovery and reset after payout, preserving progress when membership changes. Added mocked crew regression tests. Independent PvE parties and contribution-based reward review remain unfinished.
4. Character selection now stacks below 620px panel width, scrolls vertically and uses 44px selection buttons; panel height follows available space. Guide explanations now auto-size in a scrolling list; the map also scrolls, with fixed 44px map/close controls outside the scrolling content. Pending device/Studio tests.
5. Birds/drakes now use client-side oval flight paths, tangent-facing direction and shoulder-pivot wing rotation. Server creates static non-interactive parts and flight metadata; client animation is capped at 30 updates/second with a 650-stud distance cutoff. Distance audit fix: parts fade from 550 to 650 studs and hide beyond the cutoff instead of visibly freezing at their last position. Pending Studio visual, streaming and device-performance checks; other scenery still uses server tweens.

## Verification boundaries

Crew joining now requires loaded data, a chosen character and a living character near the board. Wreck/home biome navigators, world gates and the guest directory validate range. The guest directory only cycles through players who actually own a harbor, avoiding silent failed visits when plots are full. The HUD return-home action intentionally remains usable remotely. Studio prompt-flow tests remain pending.

HUD controls now use Activated for touch/mouse/controller parity. Added G to toggle the guide, J to toggle Journey, and controller B to dismiss an open panel. Shortcuts ignore handled input, focused text fields and incomplete character selection. Pending Studio controller/chat-focus tests.

Guardian wind-up/interrupt state is isolated in `GuardianAttack.lua`. Mock-free logic tests cover idle rejection, duplicate begin/resolve, character eligibility, cancellation, cooldown boundaries and independent guardians. This does not validate engine damage, visuals or multiplayer latency.

Travel now returns an explicit success result and rejects dead/missing characters. Biome, guest-visit and rescue success messages are conditional on movement succeeding; return-home forwards the actual result. Mock tests cover successful movement, velocity clearing and dead/missing-character failures. Streaming readiness still requires Studio testing.

Repeatable checks: `npm ci --ignore-scripts`, then `npm test` (all Lua suites in tests/), then `npm run build`. The dependency lockfile pins the pure-JavaScript Lua test runtime. No Xcode/native compilation is required for these mocked tests.

Guardian strikes, nearby assist payouts, route caches, salvage crates, storm cores and ancient caches now use a shared living-character/range check before awarding rewards or consuming loot. Storm cores also reject collection after the event deadline. `tests/player-runtime.lua` covers exact range boundaries, out-of-range, dead/missing characters and destroyed targets with mocks. Harbor upgrades, sanctuary, training, daily log, contract review and guest rewards now also require loaded player data and a living character within reach. Existing owner checks remain in place. Teleport/navigation interactions remain to audit.

Character selection now allows a manual retry after eight seconds without confirmation. Delayed callbacks are attempt-scoped; successful confirmation closes the panel, and the server acknowledges an existing choice without allowing replacement. Buttons use Activated for mouse/touch/gamepad. Pending Studio latency/input tests.

Rojo build success is packaging validation, not a Studio playtest. Never claim visual or runtime success without testing it. Git is currently unavailable due to Apple's Xcode license gate; continue safe development without accepting licenses or changing system tools. The authenticated GitHub CLI/API can commit verified source changes to the development branch; local Git history is not synchronized with those API commits.

Latest verification: all four regression suites, all 13 source-file Luau syntax checks and the Rojo build pass. Studio now launches, but automated file-picker input timed out before the latest place could be loaded; no in-game validation has been completed.
