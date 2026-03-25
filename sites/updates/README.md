# TubeBackdrop update feed (Vercel)

**Easiest:** connect the **repository root** to Vercel. The root [`vercel.json`](../../vercel.json) runs `npm run build` inside `sites/updates` and publishes `sites/updates/dist` (so `/appcast.xml` is live).

**Alternative:** create a Vercel project with **Root Directory** set to `sites/updates` and use only this folder’s `vercel.json`.

After deploy, set **`SUFeedURL`** in `App/Info.plist` to:

`https://<your-deployment>.vercel.app/appcast.xml`

The release workflow commits an updated `public/appcast.xml` here on each version tag.
