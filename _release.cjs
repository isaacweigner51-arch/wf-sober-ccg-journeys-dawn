const { ReplitConnectors } = require("@replit/connectors-sdk");
const fs = require("fs");

async function main() {
  const rc = new ReplitConnectors();
  const gh = await rc.createProxyFetch("github");
  const owner = "isaacweigner51-arch", repo = "wf-sober-ccg-journeys-dawn";

  // 1. Get the latest commit SHA for the tag
  const ref = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/main`)).json();
  const sha = ref.object.sha;
  console.log("HEAD sha:", sha);

  // 2. Create the release
  const rel = await (await gh(`https://api.github.com/repos/${owner}/${repo}/releases`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      tag_name: "v0.8.23",
      target_commitish: sha,
      name: "v0.8.23 — Cloud save download fix",
      body: [
        "## v0.8.23 — Cloud save download fix",
        "",
        "### What's fixed",
        "- **Cloud save download failure on Android** — the `save_data` type check was too strict; PostgREST can return JSONB as a Dictionary or as a JSON-encoded String. Both forms are now accepted.",
        "- **Session file stored empty profile** — `_save_session()` was called before `_load_account_profile()` ran, so the session file always had `account_profile={}`. Now saved after the Supabase fetch.",
        "- **Empty local save uploaded over real server data** — on a fresh Android install (gold=0, cards=0) the old code uploaded immediately, clobbering desktop progress. Upload is now guarded: only fires when local has real progress.",
        "- **UI not refreshing after cloud apply** — added explicit `show_home()` call after cloud data is merged in case a viewport-size change rendered the screen before cloud data arrived.",
        "- **recovery_challenge_progress merge crash** — was calling `int()` on a Dictionary; now merges per class key with `maxi()`.",
        "",
        "### Install",
        "Sideload `WF_Sober_CCG_0823_Mobile.apk` over the existing install. Android preserves `user://` data on APK update.",
        "",
        "### What to check in the Output panel after login",
        "```",
        "CLOUD FETCH ── save_data loaded (Dictionary, 9 sections)",
        "CLOUD SYNC ── after  : gold=<desktop_value> vials=<...> packs=<...>",
        "```"
      ].join("\n"),
      draft: false,
      prerelease: false
    })
  })).json();

  if (!rel.id) { console.error("release create failed:", JSON.stringify(rel)); process.exit(1); }
  console.log("release created:", rel.html_url);

  // 3. Upload the APK as a release asset
  const apkPath = "/home/runner/workspace/WF_Sober_CCG_0823_Mobile.apk";
  const apkData = fs.readFileSync(apkPath);
  console.log("uploading APK (%d MB)...", Math.round(apkData.length / 1024 / 1024));

  const uploadUrl = rel.upload_url.replace("{?name,label}", "");
  const upload = await gh(`${uploadUrl}?name=WF_Sober_CCG_0823_Mobile.apk`, {
    method: "POST",
    headers: { "Content-Type": "application/vnd.android.package-archive" },
    body: apkData
  });
  const asset = await upload.json();
  if (!asset.id) { console.error("upload failed:", JSON.stringify(asset).slice(0, 300)); process.exit(1); }
  console.log("APK uploaded:", asset.browser_download_url);
}

main().catch(e => { console.error(e.message); process.exit(1); });
