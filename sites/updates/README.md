# TubeBackdrop update feed (Vercel)

**Easiest:** connect the **repository root** to Vercel. The root [`vercel.json`](../../vercel.json) runs `npm run build` inside `sites/updates` and publishes `sites/updates/dist` (so `/appcast.xml` is live).

**Alternative:** create a Vercel project with **Root Directory** set to `sites/updates` and use only this folder’s `vercel.json`.

After deploy, set **`SUFeedURL`** in `App/Info.plist` to:

`https://<your-deployment>.vercel.app/appcast.xml`

The release workflow commits an updated `public/appcast.xml` here on each version tag.

### Download link on the site

Each Vercel build runs `scripts/fetch-latest-release.mjs`, which calls the GitHub API and writes **`dist/latest.json`**. The home page reads it and shows a **Download** button for the latest `.zip` on the release.

The script lists **`/releases`** (newest first) and picks the latest **non-draft** release, **including prereleases**. (GitHub’s **`/releases/latest`** endpoint omits prereleases, so ad-hoc-signed builds would otherwise look like “no release”.)

- **GitHub Releases** (not Vercel) host the binary. If [Releases](https://github.com/driezie/tubebackdrop/releases) is empty, fix **Actions → Release macOS** (needs `SPARKLE_ED_PRIVATE_KEY`, etc.).
- After a new release, trigger a Vercel redeploy (or push a commit) so `latest.json` is regenerated.

Optional Vercel env: **`GITHUB_REPO`** (`owner/name`, default `driezie/tubebackdrop`), **`GITHUB_TOKEN`** (for private repos or API rate limits).
