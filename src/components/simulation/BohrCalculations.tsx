import {bohrWorkings,scientific,PLANCK_EV_SECONDS} from '@/lib/physics/bohrWorkbench';
export function BohrCalculations({lower,upper,Z,n,emission,missed,photonEnergy,chargeSymbol='Z'}:{lower:number;upper:number;Z:number;n:number;emission:boolean;missed:boolean;photonEnergy?:number;chargeSymbol?:'Z'|'Zeff'}){
 const c=bohrWorkings(lower,upper,Z,n,emission),sign=(v:number)=>(v>0?'+':'')+v.toFixed(4);
 const supplied=photonEnergy??c.photon, displayZ=Number(Z.toFixed(6));
 const short=['Eᵢ','E𝒇','ΔE atom',emission?'Eγ emitted':'Eγ absorbed','ν photon','λ photon','rₙ','vₙ'];
 const rows=[
  ['Initial energy Eᵢ',`−13.606 × ${displayZ}² / ${c.from}²`,`${c.Ei.toFixed(4)} eV`],
  [missed?'Target energy (not reached)':'Final energy E𝒇',`−13.606 × ${displayZ}² / ${c.to}²`,`${c.Ef.toFixed(4)} eV`],
  ['Atom ΔE = E𝒇 − Eᵢ',missed?'No absorption':`${c.Ef.toFixed(4)} − (${c.Ei.toFixed(4)})`,`${missed?'0.0000':sign(c.delta)} eV`],
  [emission?'Photon emitted Eγ':'Photon absorbed Eγ',`Required gap: ${c.photon.toFixed(4)} eV`,`${supplied.toFixed(4)} eV`],
  ['Frequency ν = Eγ / h',`${supplied.toFixed(4)} / 4.135668×10⁻¹⁵`,`${scientific(supplied/PLANCK_EV_SECONDS)} Hz`],
  ['Wavelength λ ≈ 1240 / Eγ',`1240 / ${supplied.toFixed(4)}`,`${(1240/supplied).toFixed(2)} nm`],
  [`Live radius rₙ = 0.529 n²/${chargeSymbol}`,`0.529 × ${n}² / ${displayZ}`,`${c.radius.toFixed(3)} Å`],
  [`Live speed vₙ ≈ 2.188×10⁶ ${chargeSymbol}/n`,`2.188×10⁶ × ${displayZ} / ${n}`,`${scientific(c.velocity)} m/s`],
 ];
 return <aside className="af-bohr-calculations" aria-label="Live worked calculations"><h3>{missed?'No absorption':emission?'Emission':'Excitation'} · worked calculation</h3><div className="af-bohr-calculation-grid">{rows.map(([title,expression,result],i)=><div className="af-bohr-calculation" role="group" aria-label={`${title}: ${result}`} title={`${title}: ${expression} = ${result}`} key={title}><span className="af-calc-long">{title}</span><span className="af-calc-short">{short[i]}</span><code>{expression}</code><strong>{result}</strong></div>)}</div><p className="af-bohr-ledger">Now: <strong>n={n}</strong> · Eₙ=<strong>{c.currentEnergy.toFixed(3)} eV</strong><br/>Stored above n={lower}: <strong>{c.stored.toFixed(3)} eV</strong>{missed&&<span> · No photon absorbed; actual transfer = 0.</span>}<small className="af-bohr-rounding">Rounded display; calculations use full precision.</small></p></aside>;
}
