const { ReplitConnectors } = require("@replit/connectors-sdk");
const fs = require("fs");
async function main() {
  const rc = new ReplitConnectors();
  const gh = await rc.createProxyFetch("github");
  const owner = "isaacweigner51-arch", repo = "wf-sober-ccg-journeys-dawn";
  // Clean up old tag/release if exists
  const old = await (await gh(`https://api.github.com/repos/${owner}/${repo}/releases/tags/v0.8.23`)).json();
  if (old.id) {
    await gh(`https://api.github.com/repos/${owner}/${repo}/releases/${old.id}`, { method: "DELETE" });
    await gh(`https://api.github.com/repos/${owner}/${repo}/git/refs/tags/v0.8.23`, { method: "DELETE" });
    console.log("cleaned old release");
  }
  const sha = (await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/main`)).json()).object.sha;
  const rel = await (await gh(`https://api.github.com/repos/${owner}/${repo}/releases`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tag_name: "v0.8.23", target_commitish: sha,
      name: "v0.8.23 — Cloud save download fix",
      body: "Cloud save download fix.\n\nSideload `WF_Sober_CCG_0823_Mobile.apk` over the existing install.",
      draft: false, prerelease: false })
  })).json();
  if (!rel.id) { console.error("release failed:", JSON.stringify(rel)); process.exit(1); }
  console.log("release:", rel.html_url);
  // Upload APK — stream in 50 MB chunks via multipart isn't supported; try direct
  const apk = fs.readFileSync("/home/runner/workspace/WF_Sober_CCG_0823_Mobile.apk");
  const url = rel.upload_url.replace("{?name,label}", "") + "?name=WF_Sober_CCG_0823_Mobile.apk";
  console.log("uploading %d MB...", Math.round(apk.length/1024/1024));
  const up = await gh(url, { method: "POST", headers: { "Content-Type": "application/vnd.android.package-archive" }, body: apk });
  const asset = await up.json();
  if (!asset.browser_download_url) { console.error("upload failed:", JSON.stringify(asset).slice(0,300)); process.exit(1); }
  console.log("download:", asset.browser_download_url);
}
main().catch(e => { console.error(e.message); process.exit(1); });
