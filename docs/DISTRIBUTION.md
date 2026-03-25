# Building and distributing TubeBackdrop (Sparkle + notarization)

## Without Apple Developer Program (GitHub + Vercel only)

You can run the full **Sparkle + GitHub Releases + Vercel appcast** pipeline with **one GitHub secret**: `SPARKLE_ED_PRIVATE_KEY`. CI builds an **ad-hoc** signed `.app` (no Developer ID). That means:

- **Sparkle** still verifies downloads (EdDSA on the zip).
- **macOS Gatekeeper** will often warn or block on other Macs until the user overrides security settings — this is expected without Developer ID and notarization.

**Do this once:**

1. **GitHub:** Create a repository, push this project, enable **Actions**.
2. **Sparkle keys:** On a Mac, run `bash scripts/sparkle-bootstrap.sh` (or Sparkle’s `generate_keys`). Put the **public** line into `App/Info.plist` → `SUPublicEDKey`. Export the private key (`generate_keys -x key.txt`) and add repo secret **`SPARKLE_ED_PRIVATE_KEY`** (entire file contents, one line).
3. **Vercel:** [Import the repo](https://vercel.com/new). Leave **root directory empty** (the repo has a root [`vercel.json`](../vercel.json) that builds `sites/updates`). Deploy — your appcast will be at `https://<project>.vercel.app/appcast.xml`.
4. **Match the app to the feed:** Set `SUFeedURL` in [`App/Info.plist`](../App/Info.plist) to that `appcast.xml` URL, commit, and rebuild locally or cut a new tag after the change.
5. **Release:** Tag and push, e.g. `git tag v1.0.0 && git push origin v1.0.0`. The workflow uploads the zip to **GitHub Releases**, signs it for Sparkle, and commits an updated [`sites/updates/public/appcast.xml`](../sites/updates/public/appcast.xml). Vercel redeploys on that push.

Optional later: add Apple **Developer ID** certificate secrets to the same workflow for proper distribution (see below).

## Two build paths

| Path | Command | Sparkle |
|------|---------|---------|
| Quick dev (CLI binary) | `swift build` from repo root | No |
| Real `.app` for release | Xcode: open `App/TubeBackdrop.xcodeproj`, scheme **TubeBackdrop**, Archive | Yes |

Regenerate the Xcode project after changing `App/project.yml`:

```bash
cd App && xcodegen generate
```

## Xcode archive (local)

1. Open `App/TubeBackdrop.xcodeproj`.
2. Select target **TubeBackdrop** → **Signing & Capabilities**: set your **Team** and **Developer ID Application** identity (or Automatic with a paid Apple Developer account).
3. **Product → Archive**.
4. **Distribute App** → **Developer ID** → upload for **notarization** (Xcode Organizer handles `notarytool` when credentials are configured).

### Notarization (CLI)

Use App Store Connect API key (recommended for CI) or Apple ID app-specific password:

```bash
xcrun notarytool submit TubeBackdrop.zip --wait \
  --key _AuthKey_XXXXX.p8 --key-id KEYID --issuer ISSUER_UUID
```

## Sparkle signing keys

The app’s `SUPublicEDKey` lives in [`App/Info.plist`](../App/Info.plist). The **matching private key** must be available when running `sign_update` (usually as GitHub secret `SPARKLE_ED_PRIVATE_KEY`).

If you **fork** this repo, generate your own pair:

1. Download Sparkle from [releases](https://github.com/sparkle-project/Sparkle/releases) and use `bin/generate_keys`, **or** run [`scripts/sparkle-bootstrap.sh`](../scripts/sparkle-bootstrap.sh).
2. Put the printed **public** key in `App/Info.plist` under `SUPublicEDKey`.
3. Export the **private** key (`generate_keys -x private.txt`) and store its contents in GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY` (single line, base64).

## Update feed URL

`SUFeedURL` in `App/Info.plist` must match the HTTPS URL of `appcast.xml` (e.g. your Vercel deployment from [`sites/updates`](../sites/updates)).

## One-click deploy (recommended)

Workflow: [`.github/workflows/deploy-release.yml`](../.github/workflows/deploy-release.yml).

**From the terminal** (requires [GitHub CLI](https://cli.github.com/) `gh auth login`):

```bash
cd "/Users/admin/background maker"
./scripts/deploy-release.sh patch    # or: minor | major — waits with dots, then gh run watch
./scripts/deploy-release.sh set 1.2.0   # exact X.Y.Z
./scripts/deploy-release.sh --no-watch patch   # fire-and-forget
```

Raw `gh` (watch latest deploy-release run yourself):

```bash
gh workflow run deploy-release.yml --repo driezie/tubebackdrop -f bump=patch
sleep 3
gh run watch "$(gh run list --workflow=deploy-release.yml --repo driezie/tubebackdrop -L 1 --json databaseId -q '.[0].databaseId')" --repo driezie/tubebackdrop --exit-status
```

**In the GitHub UI:** **Actions → Deploy release → Run workflow**

1. Choose branch (usually `main`).
2. Pick **patch** / **minor** / **major**, or set **exact version** `X.Y.Z` (overrides bump).

The job bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in [`App/project.yml`](../App/project.yml), commits, pushes, then creates and pushes tag `vX.Y.Z`. That **starts [Release macOS](../.github/workflows/release-macos.yml)** automatically (tag push).

**End-to-end you get:** signed Sparkle zip on **GitHub Releases**, release body with a **commit changelog** since the previous `v*.*.*` tag, **appcast.xml** committed for **Vercel**, and an optional **Vercel Deploy Hook** (see below).

## GitHub Actions release

Workflow: [`.github/workflows/release-macos.yml`](../.github/workflows/release-macos.yml).

**Triggers:** push of tags matching `v*.*.*`, or **workflow_dispatch** with an existing tag name (e.g. `v1.0.1`).

**Repository secrets:**

| Secret | Purpose |
|--------|---------|
| `SPARKLE_ED_PRIVATE_KEY` | **Required.** EdDSA private key (file contents from `generate_keys -x`, one line). Must match `SUPublicEDKey` in `App/Info.plist`. |
| `APPLE_CERTIFICATE_BASE64` | Optional. Base64-encoded `.p12` for **Developer ID Application** — if set together with the two below, CI uses Developer ID instead of ad-hoc. |
| `APPLE_CERTIFICATE_PASSWORD` | Optional. `.p12` password (required with certificate). |
| `APPLE_TEAM_ID` | Optional. 10-character Team ID (required with certificate). |

**Optional notarization** (only meaningful with Developer ID): set all of `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID`. If any is missing, the workflow skips notarization.

**Ad-hoc mode:** If the three Apple secrets are not all set, the build uses `CODE_SIGN_IDENTITY=-` and the GitHub Release is marked **prerelease**.

After a successful run, the workflow commits an updated Sparkle feed to [`sites/updates/public/appcast.xml`](../sites/updates/public/appcast.xml) on the default branch (for Vercel to redeploy). Use a **git tag** that matches the release you want (e.g. `v1.0.1`); the enclosure URL uses that tag. Keep `MARKETING_VERSION` in Xcode aligned with the tag for consistent zip names (`TubeBackdrop-1.0.1.zip`).

**Optional — force Vercel after appcast push:** in the Vercel project → Settings → Git → Deploy Hooks, create a hook for **Production**, then add repository secret **`VERCEL_DEPLOY_HOOK_URL`** with the hook URL. If unset, a normal Git-connected Vercel project still redeploys when the appcast commit hits the default branch.

**“No releases” on GitHub:** Vercel “deployments” are **not** GitHub Releases. The zip appears under **Releases** only after **[Release macOS](../.github/workflows/release-macos.yml)** completes for a `v*.*.*` tag (triggered by [Deploy release](../.github/workflows/deploy-release.yml) or a manual tag). Open **Actions**, fix any failed **Release macOS** run (common: missing `SPARKLE_ED_PRIVATE_KEY`, signing, or branch protection blocking the appcast push). The Vercel home page download button reads **`latest.json`**, generated at build time from the GitHub API — after the first successful release, redeploy Vercel (or push a commit) so the button updates.

If **branch protection** blocks direct pushes to `main`, allow GitHub Actions to push, or adjust the workflows (e.g. open a PR for the version bump / appcast).

## Release ZIP layout

Sparkle expects a **zip of the `.app` bundle** at the root of the archive:

```text
TubeBackdrop-1.0.1.zip
  TubeBackdrop.app/
    Contents/...
```

Create from the built `.app`:

```bash
cd /path/to/output
ditto -c -k --sequesterRsrc --keepParent TubeBackdrop.app TubeBackdrop-1.0.1.zip
```

Then sign with Sparkle’s `sign_update` (see `.github/workflows/release-macos.yml`).
