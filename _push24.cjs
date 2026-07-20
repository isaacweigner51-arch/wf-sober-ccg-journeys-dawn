const { ReplitConnectors } = require("@replit/connectors-sdk");
const fs = require("fs");
async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
async function main() {
  const rc = new ReplitConnectors();
  const gh = await rc.createProxyFetch("github");
  const owner = "isaacweigner51-arch", repo = "wf-sober-ccg-journeys-dawn", branch = "main";
  const ref = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/${branch}`)).json();
  const baseSha = ref.object.sha;
  const commit = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/commits/${baseSha}`)).json();
  const files = ["menu.gd", "wf_v084/menu.gd", "network_manager.gd", "wf_v084/network_manager.gd", "export_presets.cfg"];
  const treeItems = [];
  for (const f of files) {
    const r = await gh(`https://api.github.com/repos/${owner}/${repo}/git/blobs`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: fs.readFileSync(f, "utf8"), encoding: "utf-8" })
    });
    const d = await r.json();
    if (!d.sha) throw new Error(`blob failed ${f}: ${JSON.stringify(d)}`);
    treeItems.push({ path: f, mode: "100644", type: "blob", sha: d.sha });
    process.stdout.write(".");
    await sleep(150);
  }
  const newTree = (await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/trees`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ base_tree: commit.tree.sha, tree: treeItems })
  })).json()).sha;
  const newCommit = (await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/commits`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: "v0.8.23 — cloud save download fix + logging", tree: newTree, parents: [baseSha] })
  })).json()).sha;
  const upd = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/refs/heads/${branch}`, {
    method: "PATCH", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sha: newCommit })
  })).json();
  console.log("\npushed:", upd.object?.sha);
}
main().catch(e => { console.error(e.message); process.exit(1); });
