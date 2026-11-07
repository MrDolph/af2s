#!/usr/bin/env bash
set -euo pipefail
command -v node >/dev/null 2>&1 || { echo 'Node.js is required.' >&2; exit 1; }
node <<'AF_SITE_LOCATION_UPDATE'
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const edits={"src/app/api/site-analytics/route.ts": [["get('days')||30", "get('days')||7"]], "src/lib/analytics/site-model.ts": [["daily:{day:", "studentLocations:SiteRow[];daily:{day:"]], "src/app/api/site-track/route.ts": [["  const result=await recordSite(", "  // Use only coarse location supplied by the hosting platform.\n  const country = req.headers.get('x-vercel-ip-country')?.trim().toUpperCase() ?? '';\n  const region = req.headers.get('x-vercel-ip-country-region')?.trim().toUpperCase() ?? '';\n  const studentLocation = /^[A-Z]{2}$/.test(country)\n    ? country + (/^[A-Z0-9]{1,3}$/.test(region) ? '-' + region : '')\n    : 'Unknown';\n  const result=await recordSite("], ["device,referrer});", "device,referrer,studentLocation});"]], "src/lib/analytics/site-store.ts": [[" redis.call('HINCRBY',KEYS[4],'views',1)", " redis.call('HINCRBY',KEYS[4],'views',1)\n if e.name~='' then\n  redis.call('HINCRBY',KEYS[4],'student-location:'..(e.studentLocation or 'Unknown'),1)\n end"], ["referrer:string};", "referrer:string;studentLocation?:string};"], ["actions:[],daily:[]", "actions:[],studentLocations:[],daily:[]"], [" return{...empty,configured:true,", " const studentLocations = rows(Object.fromEntries(\n  Object.entries(totals)\n   .filter(([key]) => key.startsWith('student-location:'))\n   .map(([key, count]) => [key.slice('student-location:'.length), count]),\n ));\n return{...empty,configured:true,studentLocations,"], ["?.seconds)||0})),people,recent};", "?.seconds)||0})).reverse(),people,recent};"]], "src/app/minitab/admin/site-analytics/page.tsx": [["const [days,setDays]=useState(30)", "const [newestFirst, setNewestFirst] = useState(true);\n const [days,setDays]=useState(7)"], ["Daily page views</h2>", "Daily page views</h2>\n <button type=\"button\" className=\"mt-2 rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900\"\n  onClick={() => setNewestFirst(value => !value)}>\n  Date order: {newestFirst ? 'Newest first ↓' : 'Oldest first ↑'}\n </button>"], ["{data.daily.map(d=>", "{[...data.daily].sort((a, b) => newestFirst ? b.day.localeCompare(a.day) : a.day.localeCompare(b.day)).map(d=>"]], "src/app/privacy/analytics/page.tsx": [["We do not record IP addresses, precise location,", "For signed-in student page views, we count approximate countries and states or regions supplied by our hosting provider. These location counts are grouped by day and region. We do not record IP addresses, precise location,"]]};
const locationSection=" <section className=\"rounded-xl border bg-white p-4 text-slate-900\">\n  <h2 className=\"text-lg font-semibold\">Student locations</h2>\n  <p className=\"text-sm text-slate-600\">Approximate country and state or region for new signed-in student page views. Counts reflect page views.</p>\n  {(data.studentLocations ?? []).length ? (\n   <div className=\"mt-3 max-h-72 overflow-auto\">\n    <table className=\"w-full text-left text-sm\">\n     <thead><tr><th scope=\"col\" className=\"p-2\">Country</th><th scope=\"col\" className=\"p-2\">State / region code</th><th scope=\"col\" className=\"p-2 text-right\">Views</th></tr></thead>\n     <tbody>{data.studentLocations.map(({key, count}) => {\n      const [country, region] = key.split('-');\n      const countryName = /^[A-Z]{2}$/.test(country)\n       ? new Intl.DisplayNames(['en'], {type: 'region'}).of(country)\n       : 'Unknown';\n      return <tr key={key} className=\"border-t\"><td className=\"p-2\">{countryName}</td><td className=\"p-2\">{region ? key : 'Unavailable'}</td><td className=\"p-2 text-right\">{count}</td></tr>;\n     })}</tbody>\n    </table>\n   </div>\n  ) : <p className=\"mt-3 text-sm text-slate-600\">No student location data for this period yet.</p>}\n </section>\n";
const root=process.cwd();
function stop(message){console.error('Stopped: '+message+' No application files changed.');process.exit(1);}
if(!fs.existsSync('package.json')||!fs.existsSync('src/app/simulations/oscillations/page.tsx'))stop('Run this patch from your A-Factor project root.');
const normalize=s=>s.replace(/\r\n/g,'\n');
const hash=s=>crypto.createHash('sha256').update(normalize(s)).digest('hex');
function safe(file){let current=root;for(const part of file.split('/')){current=path.join(current,part);try{if(fs.lstatSync(current).isSymbolicLink())stop('Symbolic link at '+file);}catch(e){if(e.code!=='ENOENT')throw e;}}}
for(const file of [...Object.keys(edits),'.stem-tutor-backups'])safe(file);
const files = {}, changed = [], conflicts = [];
for (const [file, replacements] of Object.entries(edits)) {
 if (!fs.existsSync(file)) { conflicts.push(file + ' (missing)'); continue; }
 const original = normalize(fs.readFileSync(file, 'utf8'));
 let updated = original;
 let failed = false;
 for (const [before, after] of replacements) {
  if (updated.includes(after)) continue;
  if (updated.split(before).length !== 2) { failed = true; break; }
  updated = updated.replace(before, () => after);
 }
 if (!failed && file === 'src/app/minitab/admin/site-analytics/page.tsx' && !updated.includes(locationSection)) {
  const anchor = /<section\b[^>]*>\s*<h2\b[^>]*>Most viewed pages<\/h2>/g;
  const matches = [...updated.matchAll(anchor)];
  if (matches.length !== 1) failed = true;
  else updated = updated.replace(anchor, match => locationSection + match);
 }
 if (failed) { conflicts.push(file + ' (unexpected source)'); continue; }
 if (updated !== original) { files[file] = updated; changed.push(file); }
}
if (conflicts.length) stop('Install the original site analytics first, or check these source conflicts:\n' + conflicts.join('\n'));
if(!changed.length){console.log('The analytics date and location update is already installed.');process.exit(0);}
fs.mkdirSync('.stem-tutor-backups',{recursive:true});const backup=fs.mkdtempSync('.stem-tutor-backups/site-analytics-location-'),originals=new Map();
for(const file of changed){const old=fs.existsSync(file)?fs.readFileSync(file):null;originals.set(file,old);if(old!==null){const copy=path.join(backup,file);fs.mkdirSync(path.dirname(copy),{recursive:true});fs.writeFileSync(copy,old);}}
fs.writeFileSync(path.join(backup,'manifest.json'),JSON.stringify(changed.map(file=>({file,existed:originals.get(file)!==null})),null,2));
try{for(const file of changed){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,files[file],'utf8');}}catch(error){for(const [file,old]of originals){if(old===null){if(fs.existsSync(file))fs.unlinkSync(file);}else fs.writeFileSync(file,old);}console.error('Write failed; originals restored: '+error.message);process.exit(1);}
console.log('Installed seven-day analytics, date sorting and student location totals.');
console.log('Backup: '+backup);
AF_SITE_LOCATION_UPDATE
