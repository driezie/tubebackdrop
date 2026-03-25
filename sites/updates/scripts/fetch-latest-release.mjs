#!/usr/bin/env node
/**
 * Writes dist/latest.json for the static site (download link updates on each Vercel build).
 * Env: GITHUB_REPO (default driezie/tubebackdrop), optional GITHUB_TOKEN for private/rate limits.
 */
import fs from "fs"
import https from "https"

const repo = process.env.GITHUB_REPO || "driezie/tubebackdrop"
const outDir = process.env.OUT_DIR || "dist"
const outFile = `${outDir}/latest.json`

const headers = {
  Accept: "application/vnd.github+json",
  "User-Agent": "tubebackdrop-sites-updates-build",
}
if (process.env.GITHUB_TOKEN) {
  headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers }, (res) => {
        let body = ""
        res.on("data", (c) => (body += c))
        res.on("end", () => {
          if (res.statusCode === 404) {
            resolve({ status: 404, body: null })
            return
          }
          if (res.statusCode === 403 || res.statusCode === 429) {
            resolve({ status: res.statusCode, body: null, errorBody: body.slice(0, 400) })
            return
          }
          if (res.statusCode !== 200) {
            reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 200)}`))
            return
          }
          try {
            resolve({ status: 200, body: JSON.parse(body) })
          } catch (e) {
            reject(e)
          }
        })
      })
      .on("error", reject)
  })
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true })
  const url = `https://api.github.com/repos/${repo}/releases/latest`

  let payload = { ok: false, reason: "unknown", repo }

  try {
    const { status, body, errorBody } = await getJson(url)
    if (status === 403 || status === 429) {
      payload = {
        ok: false,
        reason: "github_api_limited",
        message:
          "GitHub API rate limit (common for Vercel builds). Add env GITHUB_TOKEN in Vercel (fine-grained PAT: read access to this repo’s metadata/contents).",
        repo,
        releasesUrl: `https://github.com/${repo}/releases`,
        detail: errorBody || "",
      }
    } else if (status === 404 || !body) {
      payload = {
        ok: false,
        reason: "no_releases",
        message: "No published GitHub Release yet. Run Deploy release / Release macOS successfully once.",
        repo,
        releasesUrl: `https://github.com/${repo}/releases`,
        actionsUrl: `https://github.com/${repo}/actions`,
      }
    } else {
      const assets = body.assets || []
      const zip = assets.find((a) => /\.zip$/i.test(a.name))
      payload = {
        ok: true,
        repo,
        tag_name: body.tag_name,
        name: body.name,
        published_at: body.published_at,
        html_url: body.html_url,
        zip: zip
          ? { name: zip.name, url: zip.browser_download_url, size: zip.size }
          : null,
        releasesUrl: `https://github.com/${repo}/releases`,
      }
      if (!zip && assets.length) {
        payload.note = "Latest release has no .zip asset; check workflow upload."
      }
    }
  } catch (err) {
    payload = {
      ok: false,
      reason: "fetch_error",
      message: String(err.message || err),
      repo,
      releasesUrl: `https://github.com/${repo}/releases`,
    }
  }

  fs.writeFileSync(outFile, JSON.stringify(payload, null, 2), "utf8")
  console.log(`Wrote ${outFile} ok=${payload.ok} tag=${payload.tag_name || "—"}`)
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
