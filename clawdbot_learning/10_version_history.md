# Clawdbot/Moltbot Version History

**Last Updated:** 2026-01-29

> **IMPORTANT REBRAND (2026.1.29):** The project was renamed from **Clawdbot** to **Moltbot**. The npm package is now `moltbot`, but legacy compatibility is maintained.

---

## Quick Reference

| Item | Old (≤2026.1.25) | New (≥2026.1.29) |
|------|------------------|------------------|
| **Package Name** | `clawdbot` | `moltbot` |
| **CLI Command** | `clawdbot` | `moltbot` (with `clawdbot` compat shim) |
| **Repository** | https://github.com/clawdbot/clawdbot | Same URL (org name unchanged) |
| **Documentation** | https://docs.clawd.bot | https://docs.molt.bot |
| **Config Directory** | `~/.clawdbot/` | `~/.moltbot/` (auto-migrates from legacy) |
| **Extensions Scope** | Various | `@moltbot/*` |
| **macOS Bundle ID** | `com.clawdbot.*` | `bot.molt.*` |

---

## Version 2026.1.29 (Beta)

**Release Date:** January 29, 2026  
**Status:** Beta  
**Version Jump:** 2026.1.25 → 2026.1.29 (348+ commits)

### 🎯 Highlights

#### 1. **MAJOR REBRAND: Clawdbot → Moltbot**
- **Reason:** Trademark considerations (thanks @thewilloftheshadow)
- **Changes:**
  - npm package renamed to `moltbot`
  - CLI command: `moltbot` (with `clawdbot` compatibility shim)
  - Extensions moved to `@moltbot/*` scope
  - macOS bundle IDs updated to `bot.molt.*`
  - Logging subsystems renamed
  - Config auto-migrates from `~/.clawdbot/` to `~/.moltbot/`
  - Documentation moved to https://docs.molt.bot

#### 2. **New Channels & Plugins**
- **Twitch Plugin** (#1612) - Streaming platform integration
- **Google Chat (Beta)** (#1635) - Workspace Add-on events + typing indicator

#### 3. **Security Hardening** 🔒
- Gateway auth now **required by default** (no more `auth: none`)
- Hook token query-param deprecation for enhanced security
- Windows ACL audits for permission checking
- mDNS minimal discovery to reduce attack surface
- SSH target option injection fix (#4001)
- Security audit CLI surface exposed

#### 4. **WebChat Improvements**
- Image paste support (#1925)
- Image-only sends (#1977)
- Sub-agent announce replies visibility

#### 5. **Tooling Enhancements**
- **Per-sender group tool policies** (#1757) - Fine-grained control per user in groups
- **tools.alsoAllow** - Additive allowlist for optional plugin tools (#1762)
- Memory Search: Extra paths for indexing (#3600, thanks @kira-ariaki)

---

### 🆕 Major Changes by Category

#### **Providers**
- **Venice AI** - New integration
- **Xiaomi MiMo** - Added `mimo-v2-flash` support with onboarding flow (#3454, thanks @WqyJh)
- **Moonshot Kimi** - Updated references to `kimi-k2.5` (#2762)
- **MiniMax** - Updated API endpoint and format (#3064)

#### **Telegram**
- Quote replies (partial message replies) (#2900)
- Edit-message action (#2394, thanks @marcelomar21)
- Silent sends (#2382)
- Sticker support + vision caching (#2548, thanks @longjos)
- Link preview toggle (#1700)
- Plugin sendPayload support (#1917, thanks @JoshuaLelon)

#### **Discord**
- Configurable privileged gateway intents (GuildPresences, GuildMembers) (#2266, thanks @kentaro)
- Username resolution fixes and outbound ID mapping
- Forum thread access guards

#### **Browser**
- Browser control routed via gateway/node (#1999)
- Fallback URL matching for relay targets

#### **macOS**
- Direct gateway transport
- Preserve custom SSH usernames for remote control
- Textual bumped to 0.3.1

#### **Routing & Session Management**
- Per-account DM session scope (#3095, thanks @jarvis-sam)
- Guidance for multi-account setups

#### **Hooks**
- Configurable session-memory message count (#2681)

#### **Tools**
- Honor `tools.exec.safeBins` in allowlist checks (#2281)

#### **Control UI**
- Improved chat session dropdown refresh (#3682)
- URL confirmation flow (#3578)
- Config-save guardrails
- Chat composer auto-sizing (#2950, thanks @shivamraut101)

#### **Commands**
- Grouped `/help` and `/commands` output with Telegram pagination (#2504, thanks @hougangdev)

#### **CLI**
- **Node compile cache** for ~10% faster startup (#2808, thanks @pi0)
- Recognize versioned node binaries (e.g., `node-22`) (#2490, thanks @David-Marsh-Photo)

#### **Agents**
- Summarize dropped messages during compaction safeguard pruning (#2509, thanks @jogi47)

#### **Skills**
- Multi-image input support for Nano Banana Pro skill (#1958, thanks @tyler6204)

#### **Matrix**
- Switched plugin SDK to `@vector-im/matrix-bot-sdk`

#### **Documentation**
- New deployment guides: Northflank, Render, Oracle, Raspberry Pi, GCP, DigitalOcean
- Claude Max API Proxy guide
- Vercel AI Gateway guide
- Migration guide for moving to new machines (#2381)
- Formal verification updates
- Fly private hardening (#2289, thanks @dguido)

---

### ⚠️ Breaking Changes

1. **Gateway Auth Required**
   - `gateway.auth.mode: none` is **removed**
   - Gateway now requires `token` or `password` authentication
   - Tailscale Serve identity still allowed as alternative

---

### 🐛 Major Fixes

#### **Security**
- SSH tunnel target parsing hardened against option injection/DoS (#4001, thanks @YLChen-007)
- PATH injection prevention in exec sandbox
- File serving hardened
- DNS pinning in URL fetches
- Twilio webhook verification
- LINE webhook timing-attack edge case fixed
- Tailscale Serve identity validation
- Loopback Control UI with disabled auth flagged as critical

#### **Gateway Stability**
- Prevent crashes on transient network errors
- Suppress AbortError/unhandled rejections
- Sanitize error responses
- Clean session locks on exit (#2483, thanks @janeexai)
- Harden reverse proxy handling for unauthenticated proxied connects

#### **Config & Migration**
- Auto-migrate legacy state/config paths
- Honor state directory overrides
- Include missing dist outputs in npm tarball

#### **Telegram**
- Avoid silent empty replies (#3796)
- Improved polling/network recovery (#3013, thanks @ryancontent)
- Handle video notes (#2905, thanks @mylukin)
- Keep DM thread sessions (#2731, thanks @dylanneve1)
- Preserve reasoning tags inside code blocks (#3952, thanks @vinaygit18)
- Centralized API error logging (#2492, thanks @altryne)
- Include AccountId in native command context (#2942, thanks @Chloe-VP)

#### **Discord**
- Restore username resolution (#3131, thanks @bonald)
- Resolve outbound usernames to IDs (#2649, thanks @nonggialiang)
- Honor threadId replies
- Guard forum thread access

#### **BlueBubbles**
- Coalesce URL link previews (#1981, thanks @tyler6204)
- Improve reaction handling
- Preserve reply-tag GUIDs

#### **Voice Call**
- Prevent TTS overlap
- Validate env-var config
- Return TwiML for conversation calls

#### **Media**
- Fix text attachment MIME classification (#3628)
- XML escaping on Windows (#3750)

#### **Models**
- Inherit provider baseUrl/api for inline models (#2740, thanks @lploc94)

#### **Web UI**
- Auto-scroll on send (#2471, thanks @kennyklee)
- Fix textarea sizing (#2950)
- Improve chat session refresh (#3682)

#### **CLI/TUI**
- Resume sessions cleanly
- Guard width overflow
- Avoid spinner prompt race

#### **Slack**
- Fix file downloads failing on redirects (#1936)

#### **iMessage**
- Normalize messaging targets (#1708)

#### **Signal**
- Fix reactions and add configurable startup timeout (#1651, #1677)

#### **Matrix**
- Decrypt E2EE media with size guard (#1744)

---

## Version 2026.1.25 (Previous Stable)

**Local Version Before Update:** 2026.1.25  
**Last Commit:** `ded366d9a` (2026-01-26 14:54:54 +0000)  
**Commit Message:** "docs: expand security guidance for prompt injection and browser control"

---

## Migration Guide: Clawdbot → Moltbot

### For New Installs (Recommended)

```bash
# Install the new package
npm install -g moltbot@latest

# Config will be created at ~/.moltbot/
moltbot onboard
```

### For Existing Users

**Option 1: Auto-Migration (Recommended)**

```bash
# Update to the renamed package
npm uninstall -g clawdbot
npm install -g moltbot@latest

# Config auto-migrates from ~/.clawdbot/ to ~/.moltbot/
moltbot gateway run
```

**Option 2: Manual Migration**

```bash
# Backup your config
cp -r ~/.clawdbot ~/.clawdbot.backup

# Install new package
npm install -g moltbot@latest

# Manually move config
mv ~/.clawdbot ~/.moltbot

# Update any hardcoded paths in your scripts
# Old: clawdbot gateway run
# New: moltbot gateway run
```

**Legacy Compatibility:**
- The `clawdbot` command still works via compatibility shim
- Old config directory `~/.clawdbot/` is auto-migrated
- GitHub repository URL remains the same

---

## Update Commands

### Check Current Version

```bash
# Old way
clawdbot --version

# New way
moltbot --version
```

### Update to Latest

```bash
# If you have clawdbot installed
npm uninstall -g clawdbot
npm install -g moltbot@latest

# Or directly update
npm install -g moltbot@latest
```

### Development Channel

```bash
# Beta releases
npm install -g moltbot@beta

# Specific version
npm install -g moltbot@2026.1.29
```

---

## Key Documentation Updates

| Topic | Old URL | New URL |
|-------|---------|---------|
| Main Docs | https://docs.clawd.bot | https://docs.molt.bot |
| Installation | https://docs.clawd.bot/install | https://docs.molt.bot/install |
| Gateway | https://docs.clawd.bot/gateway | https://docs.molt.bot/gateway |
| Channels | https://docs.clawd.bot/channels | https://docs.molt.bot/channels |
| Security | https://docs.clawd.bot/gateway/security | https://docs.molt.bot/gateway/security |

---

## Notable Contributors (2026.1.29)

Special thanks to all contributors who made this release possible:

- @thewilloftheshadow - Rebrand orchestration
- @tyler6204 - BlueBubbles, Nano Banana Pro, Twitch
- @iHildy - Google Chat
- @kentaro - Discord intents
- @kira-ariaki - Memory search paths
- @marcelomar21 - Telegram edit-message
- @longjos - Telegram sticker support
- @WqyJh - Xiaomi MiMo provider
- @YLChen-007 - SSH security fix
- @vinaygit18 - Telegram reasoning tags
- @jarvis-sam - Per-account session scope
- @janeexai - Session lock cleanup
- And 100+ other contributors!

---

## Breaking Changes History

### 2026.1.29
- Gateway auth mode "none" removed (now requires token/password)

### 2026.1.24
- (No breaking changes)

### 2026.1.23
- (No breaking changes)

---

## Resources

- **Official Repository:** https://github.com/clawdbot/clawdbot (name unchanged)
- **New Documentation:** https://docs.molt.bot
- **Legacy Documentation:** https://docs.clawd.bot (may redirect)
- **NPM Package:** https://www.npmjs.com/package/moltbot
- **Changelog:** https://github.com/clawdbot/clawdbot/blob/main/CHANGELOG.md
- **Release Guide:** https://github.com/clawdbot/clawdbot/blob/main/docs/reference/RELEASING.md

---

## Quick Decision Matrix

**Should I update?**

| Scenario | Recommendation |
|----------|----------------|
| **Production use** | Wait for stable (non-beta) release |
| **Testing new features** | Update to 2026.1.29 beta |
| **Need Twitch/Google Chat** | Update required |
| **Security-conscious** | Update (major security hardening) |
| **macOS user** | Note bundle ID changes; test first |
| **Extension developer** | Update and migrate to `@moltbot/*` scope |

---

## Version Comparison Table

| Feature | 2026.1.25 | 2026.1.29 |
|---------|-----------|-----------|
| Package Name | `clawdbot` | `moltbot` |
| Gateway Auth Required | Optional | **Required** |
| Twitch Plugin | ❌ | ✅ |
| Google Chat | ❌ | ✅ (beta) |
| Venice AI | ❌ | ✅ |
| Xiaomi MiMo | ❌ | ✅ |
| Per-sender Tool Policies | ❌ | ✅ |
| SSH Security Hardening | ⚠️ | ✅ |
| Windows ACL Audits | ❌ | ✅ |
| Memory Extra Paths | ❌ | ✅ |
| Telegram Quote Replies | ❌ | ✅ |
| Telegram Stickers | ❌ | ✅ |
| Discord Privileged Intents | ❌ | ✅ |

---

**Last Update Check:** 2026-01-29  
**Local Version:** 2026.1.29  
**Latest Stable:** 2026.1.29 (beta)
