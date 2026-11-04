const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const v=require('../bmp_meijendel_data_loader.js');
(async()=>{
 const b={schema:'trim-bootstrap-presentation-v1',publication_status:'diagnostisch',source_hash:'a'.repeat(64),year_from:1958,year_to:2025,html_sha256:'b'.repeat(64)},raw=JSON.stringify(b);
 const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
 const base={schema:'meijendel-integral-release-v1',release_id:'A',mode:'local_rehearsal',presentation_approved:true,source_hash:b.source_hash,year_from:1958,year_to:2025,bootstrap:{manifest_sha256:hash(raw),html_sha256:b.html_sha256}};
 let config={...base};
 const opts={hostname:'127.0.0.1',sourceManifest:{sql_sha256:b.source_hash},sha256:async s=>hash(s),fetchImpl:async url=>url==='release-config.json'?{ok:true,json:async()=>config}:{ok:true,text:async()=>raw}};
 assert.equal((await v.loadReleaseConfig(opts)).release_id,'A');
 for(const change of [{source_hash:'c'.repeat(64)},{year_to:2026},{presentation_approved:false},{mode:'production',official_data_validated:false}]){
  config={...base,...change};await assert.rejects(()=>v.loadReleaseConfig(opts));
 }
 config={...base};await assert.rejects(()=>v.loadReleaseConfig({...opts,hostname:'external.example'}));
 console.log('OK: actieve release zonder previewvlag; bron/jaar/status/host gaan bij afwijking dicht.');
})().catch(e=>{console.error(e);process.exitCode=1});
