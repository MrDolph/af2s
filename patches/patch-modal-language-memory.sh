#!/usr/bin/env bash
set -euo pipefail
command -v node >/dev/null 2>&1 || { echo 'Node.js is required.' >&2; exit 1; }
node <<'AF_MODAL_LANGUAGE_FIX'
const fs=require('node:fs'),path=require('node:path');
const file='src/components/explorer/TopicContext.tsx';
if(!fs.existsSync('package.json')||!fs.existsSync(file)){console.error('Run from your project root after installing the modal patch.');process.exit(1);}
const current=fs.readFileSync(file,'utf8');
if(current.includes('af-explainer-language-persistence')){console.log('Language persistence fix is already installed.');process.exit(0);}
const old="onChange={event=>{const language=event.target.value as Language;setResult(prepare({topicId:result.topicId,language,params:result.params,modes:result.modes}));}}",replacement="onChange={event=>{\n      const language=event.target.value;if(!isLanguage(language))return;\n      // af-explainer-language-persistence: keep the preference and current link aligned.\n      try{localStorage.setItem('afactor-simulation-language-v1',language);}catch{}\n      try{const url=new URL(window.location.href);url.searchParams.set('afLang',language);window.history.replaceState(window.history.state,'',url.toString());}catch{}\n      setResult(prepare({topicId:result.topicId,language,params:result.params,modes:result.modes}));\n     }}";
if(!current.includes(old)){console.error('Modal differs from the expected version; no changes made.');process.exit(1);}
const next=current.replace(old,replacement);
fs.mkdirSync('.stem-tutor-backups',{recursive:true});
const backup=fs.mkdtempSync('.stem-tutor-backups/modal-language-');
fs.writeFileSync(path.join(backup,'TopicContext.tsx'),current);
fs.writeFileSync(file,next);
console.log('Modal language changes now persist across refreshes, including links with afLang.');
console.log('Backup: '+backup);
console.log('Refresh, choose English in the modal once, then refresh again to verify.');
AF_MODAL_LANGUAGE_FIX
