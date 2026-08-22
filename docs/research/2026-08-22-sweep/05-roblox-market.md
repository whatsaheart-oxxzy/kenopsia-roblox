# Roblox growth/discovery/retention for 2-4 player round-based party games (2025-2026), applied to Kenopsia (PS1-horror party game, 4 players fixed)

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

The 2025/2026 Roblox recommendation system is explicitly a retention-and-co-play machine, not a CCU machine. The official signal list (create.roblox.com/docs/discovery) ranks four primary signals — play-through rate, first-play bounce rate (measured at <60s and 61-180s), play days per user, playtime per user (capped at 60 min/user/day) — then four secondary ones, of which two are directly about small-group social play: intentional co-play days per user (joins, invites, private servers) and qualified play sessions per user. Roblox extended the window from 7 to 28 days in 2026 precisely to punish thumbnail-bait with no long-term value.

The "2-4 players is a discovery handicap" premise is measurably false. I pulled live maxPlayers from the Roblox games API on 2026-08-22: Grow a Garden runs 4-player servers with 35.86B visits (the largest game on the platform); Steal An Egg (currently #1 on Top Trending, ~830k CCU) runs 7; Steal a Brainrot runs 8; Grow a Garden 2 runs 8; Forsaken runs 9. Roblox even ships a dedicated "Fun with Friends" home sort (visible in the unauthenticated explore-api). Small servers are the current meta, not a penalty — because they maximise the co-play signal per player.

Like ratio is also not on the signal list, and the measurement backs that: Tower of Hell sits at 73.6% approval and is still on Top Trending today.

What genuinely kills a game like Kenopsia is different: (1) first-play bounce — the FTUE doc says get value across in ≤5 minutes, and Kenopsia's own measured 13-minute session with a roulette→briefing preamble risks the <60s bucket; (2) cold start — a game needing 2-4 humans with zero CCU produces empty servers and a dead loop; (3) zero persistence — PLAN.md §1 measures 0 hits for DataStore, Badge, GamePass and leaderstats live, meaning literally nothing exists to pull a player back on D1, and the whole "play days per user" family of primary signals is being left on the floor.

The biggest under-used levers for a 4-player horror party game specifically are: Roblox Plus paid private servers (up to 100 Robux per subscriber per month for ≥60 cumulative minutes in a private server they own — a 4-player game is the ideal private-server product), Party API (SocialService, shipped 2025-06-03), Experience Notifications (1/day, 13+, opt-in), Experience Events (max 10 live; 1,000 RSVPs to hit the Trending Events chart), and Moments/Captures (30-second clips, rolled out 2026-07-28) — a PS1-horror party game is unusually clip-friendly. Monetisation can stay fully non-pay-to-win via cosmetics, private servers, subscriptions and opt-in rewarded video.

## Facts

- Roblox's four PRIMARY discovery signals are: play-through rate (rate users play after seeing you in Recommended for You), first-play bounce rate (negative signal, measured in two segments: <60 seconds and 61-180 seconds), play days per user, and playtime per user — the last capped at 60 minutes per user, per game, per day.
  - *Source:* https://create.roblox.com/docs/en-us/discovery.md (fetched 2026-08-22)
- SECONDARY signals are: intentional co-play days per user ('unique days that users come back to play your game with friends, including co-play days through join, invites, or private servers'), qualified play sessions per user ('filters out accidental clicks or quick bounces'), spend days per user, and Robux spent per user.
  - *Source:* https://create.roblox.com/docs/en-us/discovery.md
- Like/dislike ratio is NOT listed among the primary or secondary ranking signals in the official discovery docs.
  - *Source:* https://create.roblox.com/docs/en-us/discovery.md (absence of the signal in the enumerated list)
- Measured counter-evidence to 'high like ratio is required': Tower of Hell has 4,306,553 up / 1,548,158 down = 73.6% approval and is currently listed in the Top Trending sort.
  - *Source:* MCP-free WebFetch of https://apis.roblox.com/search-api/omni-search?searchQuery=Tower%20of%20Hell and https://apis.roblox.com/explore-api/v1/get-sorts (2026-08-22)
- Roblox expanded the Recommended For You retention window from 7 days to 28 days: 'if short-term engagement is overvalued, the system could disproportionately favor games that win attention with exciting thumbnails but don't deliver long-term value'. Signals are split across D1, D2-7, D8-28.
  - *Source:* https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- Home surfaces/sorts named in the docs: Recommended for You, Continue Playing, Friends List, Sponsored, Curated Sorts, Standout Games, Live Events. Other surfaces: Game Details Page, Search (semantic/natural-language), Discover page (top charts, trending), Notifications (milestones, high scores, friend activity).
  - *Source:* https://create.roblox.com/docs/en-us/discovery.md
- A dedicated 'Fun with Friends' sort exists on the Roblox home/explore surface (sortId 'fun-with-friends'), alongside top-trending, up-and-coming and top-playing-now.
  - *Source:* WebFetch https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=abc200&device=computer&country=all (2026-08-22)
- MEASURED server sizes of top games (games.roblox.com/v1/games, 2026-08-22): Grow a Garden maxPlayers=4 (35,855,694,358 visits, 37.9k CCU); Steal An Egg maxPlayers=7 (829,857 CCU, #1 Top Trending); Steal a Brainrot maxPlayers=8 (72.86B visits); Grow a Garden 2 maxPlayers=8 (61.3k CCU); Forsaken maxPlayers=9 (87.2k CCU).
  - *Source:* https://games.roblox.com/v1/games?universeIds=7436755782,10563114921,7709344486,10200395747,6331902150
- MEASURED server sizes of the reference party/round games (2026-08-22): Epic Minigames 12 (2.35B visits, 3.1k CCU); Dress To Impress 13 (10.81B visits, 91.7k CCU); Dead Rails 16 (6.52B visits, 38.9k CCU); Blade Ball 16; Tower of Hell 20 (28.52B visits, 56.8k CCU); Fisch 20 (110.7k CCU); 99 Nights in the Forest 25 (29.11B visits, 374.8k CCU); DOORS 50 (7.60B visits); Pressure 50 (483.8M visits).
  - *Source:* https://games.roblox.com/v1/games?universeIds=110181652,703124385,6331902150,4367208330,7018190066,7326934954 and ...=2440500124,5203828273,4777817887,5750914919
- Party API shipped 2025-06-03: SocialService:GetPlayersByPartyId(partyId), SocialService:GetPartyAsync(partyId), read-only Player.PartyId. PartyMemberData exposes UserId, PlaceId, JobId, PrivateServerId, ReservedServerAccessCode. It does NOT work in Studio playtest, and there is no API to prompt party creation/invites from inside an experience.
  - *Source:* https://devforum.roblox.com/t/party-api-is-here-enable-connected-player-experiences-and-drive-deeper-engagement/3676068
- Roblox Parties hold up to six players, are friends-only, and let a group move between experiences together; under-13 users cannot chat in a party.
  - *Source:* https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox
- Friend-join API: SocialService:PromptGameInvite(player, experienceInviteOptions), SocialService:CanSendGameInviteAsync(player, recipientId), SocialService.GameInvitePromptClosed(player, recipientIds). ExperienceInviteOptions carries InviteUser, InviteMessageId, LaunchData (string) and PromptMessage — LaunchData is how you deep-link an invitee into a specific reserved server/room.
  - *Source:* https://create.roblox.com/docs/reference/engine/classes/SocialService and https://create.roblox.com/docs/reference/engine/classes/ExperienceInviteOptions
- Social slot reservations (slots held open for friends of players already in a server) are capped at 20 slots for places with ≤100 max players, because 'some experiences have set this reservation to a very high value' which created empty servers. Join queues reduced failed join attempts by 3%.
  - *Source:* https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621
- Roblox matchmaking can and does fail to fill existing servers, spawning 1-player servers even when capacity exists elsewhere; developers have no explicit control over when a new server spawns vs. filling an existing one.
  - *Source:* https://devforum.roblox.com/t/roblox-will-sometimes-fail-matchmaking-sending-every-single-new-player-into-their-own-server-only-filling-servers-up-to-1-player/3981356 and https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621
- Experience Notifications: delivered only to opted-in users aged 13+, via ExperienceNotificationService:PromptOptIn(); the prompt is suppressed if the user already opted in or has seen the prompt in the past 30 days. LaunchData max 200 bytes; notification type 'MOMENT'; analyticsData category for segmentation. Frequency limit is one notification per user per day per experience.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/experience-notifications.md and https://create.roblox.com/docs/cloud/reference/features/notifications
- Experience Events: maximum 10 ongoing or upcoming events at a time; surface on the experience detail page, standalone event pages, group pages and the 'Trending Events in Experiences' chart. To reach that chart an event must be active, started within the last 7 days, public, and have a minimum of 1,000 RSVPs. Players can opt into notifications for event start.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/experience-events.md and https://devforum.roblox.com/t/boosting-the-visibility-of-trending-events-in-experiences/3652586
- Moments (short-form gameplay video discovery tab) began rolling out 2026-07-28 in Canada, New Zealand and Singapore; each clip has a Join button that launches the featured experience in one tap; access is age-checked 16+.
  - *Source:* https://about.roblox.com/newsroom/2026/07/moments-new-homepage-unlocks-gaming-for-all
- Captures API lets an experience record up to 30-second gameplay clips and raise custom capture prompts on specific in-game events; an Upload API and a Recommendation API were announced to follow. Creators had to answer three new Maturity & Compliance questions by 2025-09-30 or risk 'reduced visibility'. Roblox reported >930M screenshots and >240M videos captured.
  - *Source:* https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813
- Creator Rewards (replaced Engagement-Based Payouts, live 2025-07-24): 5 Robux per day per qualifying user, where the user must be an 'Active Spender' ($9.99+ spent on Roblox in the last 60 days), must play 10+ minutes, and your experience must be one of the FIRST THREE they launch that day. Audience Expansion Reward: 35% revenue share on the first $100 of a brought-in user's platform-wide purchases, if they play 10+ minutes and the experience keeps 100+ DAU for 60 days. 60-day holding period on Earned Robux.
  - *Source:* https://create.roblox.com/docs/creator-rewards and https://github.com/Roblox/creator-docs/blob/main/content/en-us/creator-rewards.md
- Roblox Plus: subscribers get PAID PRIVATE SERVERS FOR FREE, plus 10% (months 1-2) / 20% (month 3+) discounts that Roblox subsidises so creators earn the same. Creators earn up to 100 Robux per subscriber when that subscriber spends at least 60 cumulative minutes over the last 30 days in a paid private server they created in your game, plus 250 Robux/month for 3 months (750 total) per Plus signup driven from PromptRobloxSubscriptionPurchase, plus 10% of in-experience Robux transfers (10-500 Robux each).
  - *Source:* https://create.roblox.com/docs/production/monetization/roblox-plus
- Private servers are monetised as a monthly Robux fee set by the creator; changing the price CANCELS ALL ACTIVE SUBSCRIPTIONS; players under 13 may be unable to join private servers depending on privacy/parental settings.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/private-servers.md
- Subscriptions: priced at any amount ≥49 Robux, or local currency at $2.99/$4.99/$7.99/$9.99/$14.99. Local-currency subs pay 70% of value in month 1 and 100% thereafter; Robux subs pay 70% every month. You may not sell mutually exclusive/tiered subscriptions, and you may not gate a benefit behind extra requirements after purchase. API: MarketplaceService:GetUserSubscriptionStatusAsync / PromptSubscriptionPurchase / GetSubscriptionProductInfoAsync.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/subscriptions.md
- Badges: up to 5 badges can be created free per 24-hour GMT period per game; extra badges cost 100 Robux each. Awarded server-side via BadgeService:AwardBadgeAsync(); check with UserHasBadgeAsync(); icons are 512x512 and cropped to a circle.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/badges.md
- Official FTUE/retention guidance: the first-time user experience should be complete 'ideally in 5 minutes or less after entering your game'; ship smaller updates every 2-4 weeks and larger feature updates every 2-3 months; use Experiments (A/B) on individual tutorial steps and on starting-currency grants.
  - *Source:* https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/retention.md and https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/onboarding.md
- Retention metric definitions used by the ranking system: D1 = first played on date X and returned the next day; D7 = returned after 1 week; D30 = returned after 1 month. Roblox now also exposes New User First Session Retention and retention by acquisition source with genre benchmark sets.
  - *Source:* https://create.roblox.com/docs/production/analytics/retention and https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157
- Third-party 2025 benchmark tiers for Roblox D1 retention: <20% critical, 20-30% below average, 30-40% good, 40-50% excellent, 50%+ top 5%. (Treat as directional — not an official Roblox figure.)
  - *Source:* https://rolearn.dev/guidance/first-week-retention-optimization/
- Device split (third-party, Q4 2025): ~80% of Roblox sessions are mobile, ~17% PC, ~3% console; mobile is >52% of platform revenue. But only ~24% of players play exclusively on mobile — the majority are cross-platform. PlayStation was ~3% of total playtime (374M hours in Q2 2025).
  - *Source:* https://rowatcher.com/news/mobile-vs-desktop-on-roblox-who-s-playing-what-in-2026 and https://gamedevreports.substack.com/p/newzoo-roblox-as-a-platform-in-2025
- Platform scale: users spent 123.9 billion hours on Roblox in 2025, averaging 2.7 hours per DAU per day; DAU was 111.8M in Q2 2025 and 144M in Q4 2025.
  - *Source:* https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/rblx-20251231.htm (10-K FY2025) and https://fintool.com/news/roblox-q4-earnings-user-growth-surge
- Rewarded video ads: opt-in, 6-30 seconds, 13+ only, exchanged for creator-defined rewards (extra lives, currency boosts, shortcuts); average completion rate over 80%, some experiences over 90%. 61% of DAU (50M+) are 13+ and eligible.
  - *Source:* https://about.roblox.com/newsroom/2025/04/roblox-scales-video-ads-partners-with-google
- Standout Games is a curated Home sort explicitly for novel games — selection favours unique mechanics, distinctive visuals and underrepresented genres, with no numeric CCU/engagement threshold; entry is by creator nomination via survey. Console/mobile optimisation, R15 + layered accessories and experience events are listed as (non-mandatory) positives.
  - *Source:* https://create.roblox.com/docs/creator-programs/todays-picks-home
- Reference loop timings: Tower of Hell = 8-minute tower timer, no checkpoints, timer accelerates each time a player finishes; 99 Nights in the Forest = 4.5-minute day/night cycle (3 min day, 1.5 min night) with a 3-7 hour full run; Dead Rails average session ~18 minutes with a 45-Robux revive and Bonds-gated class unlocks; Dress to Impress = themed round + runway + 1-5 star peer voting, coins from placement plus daily login rewards.
  - *Source:* https://towerofhell.wiki/ , https://99-nights-in-the-forest.fandom.com/wiki/Days , https://www.maxpowergaming.co/post/how-dead-rails-became-hottest-roblox-game , https://pixeltwelve.com/articles/dress-to-impress-beginner-guide
- Approval ratios measured today for reference titles: Blade Ball 93.5%, DOORS 93.0%, Dead Rails 92.6%, Fisch 90.6%, Epic Minigames 90.6%, Dress To Impress 90.5%, 99 Nights 90.5%, Grow a Garden 89.9%, Pressure 86.6%, Steal a Brainrot 85.3%, Forsaken 84.7%, Tower of Hell 73.6%.
  - *Source:* Computed from https://apis.roblox.com/search-api/omni-search totalUpVotes/totalDownVotes fetched 2026-08-22
- Kenopsia's own measured state (project doc, itself derived from a live place read): 4 players/server, one room per server, ~13 min session with BIRD HUNTING alone ~6 min (4 legs x 90s), loop = Roulette -> Info/Briefing -> Trial -> Scoreboard -> VIABLE/REJECTED, zero persistence (0 hits for DataStore, Badge, GamePass, leaderstats), StreamingEnabled = false.
  - *Source:* C:\Users\Asus\Claude\Kenopsia_Roblox Project\PLAN.md section 1 'Gemessener Ist-Stand'

## Problems

### Zero persistence means zero D1 pull — and it starves three of the four primary ranking signals

- **Evidence:** PLAN.md §1 measures '0 Treffer für DataStore, Badge, GamePass, leaderstats' in the live place 110672791536316. Roblox's primary signals include play days per user (D1, D2-7, D8-28) and playtime per user; secondary include spend days and Robux spent.
- **Impact:** Nothing exists that a player can lose by not returning tomorrow. Play days per user is structurally pinned near 1.0, which is the single heaviest family of signals in Recommended for You, and the 28-day window (2026 change) makes this worse, not better.
- **Fix idea:** Ship a minimal profile DataStore (ProfileService-style session lock) on day one: total runs, VIABLE count, per-trial personal bests, a daily login streak, and 5 free badges/day for first-VIABLE, first-perfect-trial, 3-day streak, all-12-trials-seen, and a co-op-only badge that requires 3+ humans.

### The 13-minute session with a roulette/briefing preamble is a first-play-bounce trap

- **Evidence:** First play bounce rate is a named primary NEGATIVE signal measured at <60s and 61-180s (create.roblox.com/docs/discovery). Kenopsia's loop is Roulette → Info/Briefing → Trial, session ~13 min, with BIRD HUNTING alone ~6 min. Retention doc: FTUE should be done 'ideally in 5 minutes or less'.
- **Impact:** A brand-new solo arrival who lands mid-round, watches a roulette and a briefing, and then waits for 2-4 humans can easily exceed 60 seconds before touching gameplay — that lands directly in the worst-scoring bucket, and it also suppresses 'qualified play sessions'.
- **Fix idea:** Guarantee player input within ~20 seconds of spawn: a walkable, interactive holding area with a one-button solo mini-trial (a scored practice run of the next trial) that runs while matchmaking resolves, and hard-cap first-round briefing to ~10 seconds for first-time users (skip-on-repeat).

### Cold start: a 2-4 human-required loop at 0 CCU is self-extinguishing

- **Evidence:** devforum threads document exactly this failure mode for min-player round games; Roblox matchmaking is separately documented to sometimes spawn 1-player servers even when capacity exists.
- **Impact:** Early players arrive to an empty server, wait, leave in under 60s — which simultaneously spikes the negative bounce signal and reduces play-through rate, so recommendations get worse, so fewer players arrive. The death spiral is mechanically encoded in the ranking system.
- **Fix idea:** Make every trial fully scoreable and fun at n=1 against ghost/AI opponents (record real player runs as ghosts once you have any), so 'waiting' never exists; start the round at 1 player and back-fill mid-round into the next trial. Only then use social slots (max 20 for ≤100 max-player places) and Party spawn-together.

### No use of the co-play signal despite being a co-op game — the one signal a 4-player game should dominate

- **Evidence:** 'Intentional co-play days per user' is a named secondary signal and explicitly counts joins, invites AND private servers; Roblox ships a 'Fun with Friends' home sort; Party API (SocialService, 2025-06-03) exists. PLAN.md shows no invite/party/private-server integration.
- **Impact:** A 4-player horror game is the single best possible shape for this signal and is currently scoring zero on it. This is the cheapest available discovery win.
- **Fix idea:** Add SocialService:PromptGameInvite with ExperienceInviteOptions.LaunchData deep-linking straight into the inviter's room; read Player.PartyId to spawn party members into the same room and give them a shared cosmetic marker; enable private servers.

### Private servers are unimplemented, and for a 4-player game that is also the best non-P2W revenue line on the platform

- **Evidence:** Roblox Plus pays creators up to 100 Robux per subscriber per month when that subscriber spends ≥60 cumulative minutes over 30 days in a PAID private server they created in your game; Plus subscribers get paid private servers free (create.roblox.com/docs/production/monetization/roblox-plus).
- **Impact:** A group of 4 friends is precisely the private-server customer. Missing this loses recurring Robux, loses the co-play signal, and loses the 'a group has a permanent home in my game' retention hook.
- **Fix idea:** Enable private servers at a modest monthly Robux price and never change the price afterwards (changing it cancels every active subscription). Add private-server-only toggles (trial playlist, round length, unlocked mirror/cosmetics) that are cosmetic/convenience, not power.

### StreamingEnabled = false on a mobile-dominated platform

- **Evidence:** PLAN.md §1: 'Streaming | StreamingEnabled = false'. ~80% of Roblox sessions are mobile (third-party Q4 2025), and mobile is >52% of platform revenue.
- **Impact:** Longer initial load and higher memory on low-end Android is the most common cause of a sub-60-second bounce that has nothing to do with game design — it poisons the primary negative signal before the player ever sees a trial.
- **Fix idea:** Turn on instance streaming with a tuned StreamingTargetRadius per arena, audit texture/mesh budget, and measure time-to-first-input on a low-end Android device as an explicit release gate.

### No clippable-moment capture in a game whose entire aesthetic is clip bait

- **Evidence:** Moments launched 2026-07-28 with one-tap Join from every clip; the Captures API records up to 30-second clips and supports custom in-experience capture prompts; >240M videos already captured.
- **Impact:** Moments is currently the newest and least-contested discovery surface on Roblox, and a PS1-horror party game with 4 friends screaming is the highest-converting content type for it. Not instrumenting capture prompts is leaving the surface entirely to competitors.
- **Fix idea:** Fire a capture prompt on exactly the moments worth sharing: elimination by the judging machine, a REJECTED verdict, a last-second VIABLE, and the canteen finale. Keep it to ~2-3 prompts per session so it does not become noise.

### No notification / event calendar surface, so there is no owned re-engagement channel

- **Evidence:** Experience Notifications allow one notification per user per day to opted-in 13+ users with 200 bytes of LaunchData; Experience Events allow 10 live events and reach the Trending Events chart at 1,000 RSVPs.
- **Impact:** Without these, every returning visit must be re-earned through the algorithm. With them, you own a direct D1/D7 lever that feeds the exact signals the algorithm ranks on.
- **Fix idea:** Prompt opt-in once, after a player's first VIABLE verdict (the prompt is suppressed for 30 days after being shown, so spend it well). Then run a weekly 'Night Shift' event with a rotating trial playlist and a leaderboard reset.

### Playtime-per-user is capped at 60 min/day, so long sessions are worth less than repeat days

- **Evidence:** 'Playtime per user … There is a maximum of 60 minutes per user, per game, per day' (create.roblox.com/docs/discovery); play days per user is tracked separately across D1, D2-7, D8-28.
- **Impact:** Designing toward one long marathon session is strictly worse for ranking than designing toward 3-4 short visits across a week. A 13-minute session is already fine; what is missing is the reason to come back on separate days.
- **Fix idea:** Put the reward gate on DAYS, not on minutes: daily rotating trial playlist, daily streak, weekly OrderedDataStore leaderboard reset, and a 'shift' currency that only accrues once per calendar day.

## Opportunities

### P0 — Solo-playable / ghost-opponent mode so a round NEVER waits for humans; back-fill joiners into the next trial.

- **Why:** Directly attacks the two highest-weighted negative outcomes: first-play bounce <60s and low play-through rate. It also makes every other item on this list possible, because none of them matter if the first arrival sees an empty room. Ghosts of real recorded runs later double as a social hook.
- **Cost:** L
- **Source:** https://create.roblox.com/docs/en-us/discovery.md (first play bounce rate, primary signal) + https://devforum.roblox.com/t/how-to-handle-the-problem-of-minimum-players-to-start-a-round/4614349

### P0 — DataStore profile + daily login streak + 5 free badges/day.

- **Why:** 'Play days per user' across D1, D2-7 and D8-28 is a primary signal and Kenopsia currently scores the floor on it. Badges are free (5 per 24h per game, 100 Robux beyond) and are awarded server-side with one call, so this is the highest signal-per-line-of-code item available.
- **Cost:** M
- **Source:** https://create.roblox.com/docs/en-us/discovery.md + https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/badges.md

### P0 — First 20 seconds: spawn straight into an interactive holding area with a one-button scored practice of the upcoming trial; skip/shorten the briefing for first-time users.

- **Why:** Official FTUE guidance is ≤5 minutes total, and bounce is measured at <60s. Getting a controller input and a score in the first 20 seconds converts 'watching' into 'playing' before the bounce clock fires.
- **Cost:** M
- **Source:** https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/retention.md + https://create.roblox.com/docs/en-us/discovery.md

### P1 — SocialService:PromptGameInvite with ExperienceInviteOptions.LaunchData that deep-links the invitee into the inviter's exact room/reserved server, surfaced at the verdict screen ('call someone for the next shift').

- **Why:** Feeds 'intentional co-play days per user' (a named secondary signal that explicitly counts invites) and, in a 4-player game, one accepted invite is 25% of the server. Placing the prompt at the emotional peak (VIABLE/REJECTED verdict) is where conversion is highest.
- **Cost:** S
- **Source:** https://create.roblox.com/docs/reference/engine/classes/SocialService + https://create.roblox.com/docs/reference/engine/classes/ExperienceInviteOptions + https://create.roblox.com/docs/en-us/discovery.md

### P1 — Party API integration: read Player.PartyId, keep party members in one room, give the party a shared visual treatment (matching subject numbers / a shared VHS timestamp).

- **Why:** Parties are friends-only and up to 6, which maps almost exactly to a 4-player room; Roblox built the API specifically to reward experiences that respect party grouping, and co-play is a ranked signal. Note it cannot be tested in Studio playtest, so budget for published test builds.
- **Cost:** M
- **Source:** https://devforum.roblox.com/t/party-api-is-here-enable-connected-player-experiences-and-drive-deeper-engagement/3676068 + https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox

### P1 — Enable PAID private servers at a fixed monthly Robux price, with cosmetic/convenience host controls (choose the trial playlist, round length, lights on/off).

- **Why:** Triple win: private servers count toward intentional co-play, they are non-pay-to-win recurring revenue, and under Roblox Plus a creator earns up to 100 Robux per subscriber per month when that subscriber spends ≥60 cumulative minutes over 30 days in a paid private server they own. A 4-player friend group is the ideal customer. Critical: never change the price later — that cancels every active subscription.
- **Cost:** S
- **Source:** https://create.roblox.com/docs/production/monetization/roblox-plus + https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/private-servers.md

### P1 — Captures API prompts on the four most clippable beats (elimination, REJECTED verdict, last-second VIABLE, canteen finale), max ~3 prompts/session.

- **Why:** Moments is the newest, least-saturated discovery surface (rolled out 2026-07-28) and every clip carries a one-tap Join button back into your game. PS1-horror + 4 screaming friends is the exact content format that surface rewards. 30-second clip limit fits a trial round almost perfectly.
- **Cost:** S
- **Source:** https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813 + https://about.roblox.com/newsroom/2026/07/moments-new-homepage-unlocks-gaming-for-all

### P2 — Experience Notifications: one opt-in prompt fired right after a player's first VIABLE verdict, then at most one notification/day ('your shift starts in 10 minutes', 'a friend was rejected in the Canteen').

- **Why:** An owned D1/D7 channel that does not depend on the algorithm. 13+ opt-in only, 200 bytes of LaunchData to route them straight back to the right room, and analyticsData categories so you can measure which notification copy actually returns players. The opt-in prompt is suppressed for 30 days once shown, so timing it at the peak matters.
- **Cost:** M
- **Source:** https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/experience-notifications.md

### P2 — Weekly 'Night Shift' Experience Event with a rotating trial playlist and a leaderboard reset; keep up to 10 events queued.

- **Why:** Events surface on the detail page, event pages and the Trending Events chart (needs 1,000 RSVPs + started within 7 days), and players can opt into a start notification. It converts 'update cadence' (docs recommend every 2-4 weeks) into an actual discovery surface rather than an invisible patch note.
- **Cost:** S
- **Source:** https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/experience-events.md + https://devforum.roblox.com/t/boosting-the-visibility-of-trending-events-in-experiences/3652586

### P2 — OrderedDataStore weekly leaderboards physically present in the lobby (per-trial best, most VIABLE verdicts, longest streak), reset weekly.

- **Why:** Gives a reason to return on a NEW DAY rather than to play longer today — which matters because playtime is capped at 60 min/user/day for ranking while play days are not. In a PS1-horror frame a wall of etched subject numbers is diegetic, not UI clutter.
- **Cost:** M
- **Source:** https://create.roblox.com/docs/en-us/discovery.md (playtime cap vs play days) + https://create.roblox.com/docs/cloud-services/data-stores/ordered-data-stores

### P2 — Non-pay-to-win cosmetic economy: masks/uniform variants/CRT & VHS screen filters/emotes/subject-number plates, bought with a daily-capped soft currency or Robux, never affecting trial outcomes.

- **Why:** Feeds the two spend signals (spend days per user, Robux spent per user) without touching fairness — critical for a scored competitive party game where any advantage destroys the like ratio and the co-play loop. Dress To Impress and Forsaken both monetise almost entirely on cosmetics/XP-flavour while keeping currency earnable by winning rounds.
- **Cost:** M
- **Source:** https://create.roblox.com/docs/en-us/discovery.md + https://forsaken2024.fandom.com/wiki/Gamepasses_%26_Products + https://pixeltwelve.com/articles/dress-to-impress-beginner-guide

### P2 — Mobile-first pass: instance streaming on, 44x44px minimum touch targets, keep the bottom ~30% of screen clear of custom UI, cap simultaneous ability inputs at 4-5, verify time-to-first-input on a low-end Android.

- **Why:** ~80% of sessions are mobile and mobile is >52% of platform revenue; a game that is unplayable on a 3-year-old Android bounces in the <60s bucket for reasons that have nothing to do with the design. Also a soft prerequisite for the Standout Games curation sort, which lists mobile/console optimisation as a positive.
- **Cost:** M
- **Source:** https://rowatcher.com/news/mobile-vs-desktop-on-roblox-who-s-playing-what-in-2026 + https://create.roblox.com/docs/projects/cross-platform + https://create.roblox.com/docs/creator-programs/todays-picks-home

### P2 — Nominate for Standout Games curation.

- **Why:** It is a hand-curated Home sort explicitly for novel mechanics, distinctive visuals and underrepresented genres, with NO numeric CCU threshold — which is the rare discovery path that a small, weird, well-made PS1-horror party game can actually win. Cost is a survey submission.
- **Cost:** S
- **Source:** https://create.roblox.com/docs/creator-programs/todays-picks-home

### P3 — Icon/thumbnail/title iteration treated as a measured experiment, with the icon showing the judging machine and a 4-player group, not just a logo.

- **Why:** Play-through rate (how often people click AND play after seeing you in Recommended for You) is a PRIMARY signal, and it is the only primary signal you can move without shipping gameplay. Docs warn against giveaway language ('Robux! Play now!') and metadata that does not match content.
- **Cost:** S
- **Source:** https://create.roblox.com/docs/en-us/discovery.md

### P3 — Opt-in rewarded video ads for a cosmetic reroll or an extra practice run — never for scoring power.

- **Why:** 6-30s opt-in format with >80% average completion and 13+ gating; monetises the large non-spending share of a young audience without touching trial fairness. Keep it out of the competitive loop entirely.
- **Cost:** M
- **Source:** https://about.roblox.com/newsroom/2025/04/roblox-scales-video-ads-partners-with-google

### P3 — Consider a 12-24 player LOBBY place that teleports groups of 4 into reserved trial servers, INSTEAD OF raising the trial player count.

- **Why:** Keeps the 4-player design decision (PLAN.md E1) intact while solving the social-proof and empty-server problem: a visibly populated lobby, friends visible before the run, and a natural place for leaderboards, cosmetics and the event calendar. Measured evidence says the small room itself is not the problem — Grow a Garden runs 4-player servers at 35.86B visits — so spend the effort on the lobby, not on inflating the room.
- **Cost:** L
- **Source:** https://games.roblox.com/v1/games?universeIds=7436755782 (maxPlayers=4, 35.86B visits, 2026-08-22) + https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621

### P3 — Optional subscription ('Night Shift Pass') at $2.99 or ≥49 Robux for a monthly cosmetic drop + private-server perk.

- **Why:** Local-currency subscriptions pay 70% in month 1 and 100% every month after — the best revenue share on the platform — and a recurring benefit is itself a return-visit reason. Rules forbid mutually exclusive/tiered subs and forbid gating a benefit behind extra requirements after purchase, so design it as one flat tier.
- **Cost:** M
- **Source:** https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/subscriptions.md

### P3 — Instrument for Creator Rewards: get players to 10+ minutes and try to be one of the first three experiences they open that day.

- **Why:** 5 Robux/day per qualifying Active Spender is free money that rewards exactly the behaviour the ranking algorithm also rewards. Kenopsia's ~13-minute session already clears the 10-minute bar — the lever is the 'first three experiences of the day' rule, which is what notifications, streak resets and a fixed daily event time are for.
- **Cost:** S
- **Source:** https://create.roblox.com/docs/creator-rewards

## Open questions

- No official Roblox source could be found for the 80/17/3 mobile/PC/console split — it traces to third-party trackers (RoWatcher) and Newzoo, not to a Roblox filing. Roblox's 10-K reports 123.9B hours and 2.7h/DAU but does not break hours down by platform. If device mix matters to a decision, the only trustworthy number is your OWN Creator Analytics platform breakdown once the game has traffic.
- DAU figures conflict across sources within months of each other (111.8M Q2 2025, 144M Q4 2025, 132M cited for Q1 2026). Do not build any model on a specific platform DAU number.
- Roblox publishes the ORDER of ranking signals (primary vs secondary) but not their WEIGHTS. 'Signal importance rankings' are said to be visible per-game in Creator Analytics — that dashboard is the only way to know which signal Kenopsia is actually losing on, and it needs real traffic first.
- No official Roblox benchmark for D1/D7 by genre was retrievable; the 20/30/40/50% tiers are third-party (rolearn.dev) and the percentile tables sit behind the GameAnalytics 2025 Roblox Benchmark Report. Roblox's own 'select your benchmark set' analytics feature (devforum 4010157) is the authoritative substitute.
- Per-game average session length is not exposed by any public Roblox API. The Dead Rails '18 minutes' figure is a single third-party article. Every session-length comparison in this report should be treated as directional, not measured.
- Ripull Minigames could not be resolved via omni-search or the place-ID lookup (place 286090429 resolves to Arsenal). Either it has been renamed/delisted or the place ID is wrong — needs a direct link from the user if that reference matters.
- Moments is only live in Canada, New Zealand and Singapore as of 2026-07-28 and is age-gated at 16+. Whether it reaches Kenopsia's target region and age band in a useful timeframe is unknown, and the Upload API / Recommendation API were still 'coming' as of the announcement.
- Party API cannot be exercised in Studio playtest, so any party-aware room assignment logic needs a published test place and real party members to verify — worth confirming before scoping it.
- Whether Kenopsia should ship a separate lobby place at all is a real fork: measured evidence (Grow a Garden at maxPlayers=4) says small rooms are not a ranking handicap, so the lobby's value is social proof and surface area, not discovery. That tradeoff needs an explicit decision from the user before an L-sized build is started.
- Under-13 players may be unable to join private servers depending on privacy/parental settings — if Kenopsia's expected audience skews under 13, the private-server/Roblox-Plus revenue thesis weakens substantially and should be re-checked against the intended age rating.
