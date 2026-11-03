import data from './organisms.json';
export type Organism={id:string;common:string;name:string;group:string;ranks:(string|null)[];aliases:string[];note:string;source:string;checked:string};
export const organisms:Organism[]=data;
export const ranks=['Domain','Kingdom','Phylum / Division','Class','Order','Family','Genus','Species'] as const;
export const organismGroups=['Animals','Plants','Fungi','Protists and algae','Bacteria and archaea'];
export function rankValue(organism:Organism,rank:number){return organism.ranks[rank]||null;}
export function filterOrganisms(search:string,group='All'){
 const terms=search.trim().toLocaleLowerCase('en').split(/\s+/).filter(Boolean);
 return organisms.filter(o=>(group==='All'||o.group===group)&&terms.every(term=>[o.common,o.name,...o.aliases].join(' ').toLocaleLowerCase('en').includes(term)));
}
