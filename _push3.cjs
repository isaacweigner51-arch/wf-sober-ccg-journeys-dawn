const { ReplitConnectors } = require("@replit/connectors-sdk");
const fs = require("fs");
const path = require("path");

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const rc = new ReplitConnectors();
  const gh = await rc.createProxyFetch("github");
  const owner = "isaacweigner51-arch", repo = "wf-sober-ccg-journeys-dawn", branch = "main";

  const ref = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/${branch}`)).json();
  const baseSha = ref.object.sha;
  const commit = await (await gh(`https://api.github.com/repos/${owner}/${repo}/git/commits/${baseSha}`)).json();
  const baseTreeSha = commit.tree.sha;
  console.log('base sha:', baseSha, 'tree:', baseTreeSha);

  const allFiles = [
    { path: 'data/cards.json', enc: 'utf-8' },
    { path: 'data/version_manifest.json', enc: 'utf-8' },
    { path: 'wf_v084/data/cards.json', enc: 'utf-8' },
    { path: 'wf_v084/data/version_manifest.json', enc: 'utf-8' },
    ...['jd-150','jd-151','jd-152','jd-153','jd-154','jd-158','jd-159','jd-160','jd-161','jd-162','jd-166','jd-167','jd-168','jd-169','jd-170','jd-174','jd-175','jd-176','jd-177','jd-178','jd-182','jd-183','jd-184','jd-185','jd-186','jd-187','jd-188','jd-189','jd-190','jd-191','jd-192','jd-193','jd-194','jd-195','jd-196','jd-197','jd-198','jd-199','jd-200','jd-201','jd-202','jd-203','jd-204','jd-205','jd-206','jd-207','jd-208','jd-209']
      .flatMap(id => [
        { path: `assets/cards/full/${id}.jpg`, enc: 'base64' },
        { path: `wf_v084/assets/cards/full/${id}.jpg`, enc: 'base64' },
      ])
  ];

  // Upload blobs in parallel batches of 6
  const treeItems = [];
  for (let i = 0; i < allFiles.length; i += 6) {
    const batch = allFiles.slice(i, i + 6);
    const results = await Promise.all(batch.map(async ({ path: p, enc }) => {
      const content = enc === 'base64' ? fs.readFileSync(p).toString('base64') : fs.readFileSync(p, 'utf8');
      const r = await gh(`https://api.github.com/repos/${owner}/${repo}/git/blobs`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content, encoding: enc })
      });
      const d = await r.json();
      if (!d.sha) throw new Error(`blob failed for ${p}: ${JSON.stringify(d)}`);
      return { path: p, mode: '100644', type: 'blob', sha: d.sha };
    }));
    treeItems.push(...results);
    process.stdout.write(`  ${i + batch.length}/${allFiles.length} blobs\r`);
    await sleep(150);
  }
  console.log(`\n${treeItems.length} blobs ready`);

  // Create tree in chunks — build a sub-tree first for images, then combine
  // Actually, just do one tree with base_tree
  const treeRes = await gh(`https://api.github.com/repos/${owner}/${repo}/git/trees`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ base_tree: baseTreeSha, tree: treeItems })
  });
  const treeText = await treeRes.text();
  const treeData = JSON.parse(treeText);
  if (!treeData.sha) throw new Error('tree failed: ' + treeText.slice(0, 300));
  console.log('tree sha:', treeData.sha);

  const commitRes = await gh(`https://api.github.com/repos/${owner}/${repo}/git/commits`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: 'Rebalance rarities: 3 Legendaries/class; +7 Bronze +5 Silver per class; 195 cards total',
      tree: treeData.sha, parents: [baseSha]
    })
  });
  const newCommit = (await commitRes.json()).sha;
  console.log('commit sha:', newCommit);

  const upd = await gh(`https://api.github.com/repos/${owner}/${repo}/git/refs/heads/${branch}`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sha: newCommit, force: false })
  });
  const updData = await upd.json();
  console.log('pushed:', updData.object?.sha || JSON.stringify(updData).slice(0, 200));
}

main().catch(e => { console.error(e.message || e); process.exit(1); });
