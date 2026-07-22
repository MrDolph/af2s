// ── X-ray production ──────────────────────────────────────────────────────────
// Electrons accelerated through V kilovolts strike a metal target.
//   Max photon energy = eV  →  minimum wavelength (Duane–Hunt limit):
//     λmin = hc / eV
// Spectrum = continuous bremsstrahlung (Kramers' law shape)
//          + characteristic Kα/Kβ lines once V exceeds the excitation energy.

export const H = 6.626e-34;
export const C = 3e8;
export const E_CHARGE = 1.602e-19;

// λmin in nanometres for tube voltage in kV.  λmin(nm) ≈ 1.24 / V(kV)
export function lambdaMinNm(kV: number) {
  return kV > 0 ? (H * C) / (E_CHARGE * kV * 1000) * 1e9 : Infinity;
}
export function maxPhotonEnergyKeV(kV: number) {
  return kV; // eV of electron = photon max, numerically kV → keV
}
export function electronSpeedFraction(kV: number) {
  // Classical estimate v = √(2eV/m) as a fraction of c (fine for a school sim).
  const v = Math.sqrt((2 * E_CHARGE * kV * 1000) / 9.109e-31);
  return Math.min(v / C, 0.99);
}

// Molybdenum target (the classic textbook case):
export const MO_K_ALPHA_NM = 0.071;
export const MO_K_BETA_NM = 0.063;
export const MO_EXCITATION_KV = 20;

// Continuous spectrum via Kramers: I(λ) ∝ (λ/λmin − 1)/λ³, plus Gaussian
// characteristic peaks when the tube voltage can excite them.
export function xraySpectrum(kV: number, current: number, lambdaMaxNm = 0.14, points = 160) {
  const lMin = lambdaMinNm(kV);
  const data: { lambda: number; i: number }[] = [];
  const showLines = kV >= MO_EXCITATION_KV;
  for (let p = 0; p <= points; p++) {
    const l = (p / points) * lambdaMaxNm;
    let I = 0;
    if (l > lMin && l > 0) {
      I = ((l / lMin - 1) / (l * l * l)) * 2e-5 * current;
    }
    if (showLines) {
      const g = (c0: number, s: number, a: number) => a * Math.exp(-((l - c0) ** 2) / (2 * s * s));
      I += g(MO_K_ALPHA_NM, 0.0012, 9 * current) * (l > lMin ? 1 : 0);
      I += g(MO_K_BETA_NM, 0.0012, 5 * current) * (l > lMin ? 1 : 0);
    }
    data.push({ lambda: +l.toFixed(4), i: +I.toFixed(3) });
  }
  return data;
}
