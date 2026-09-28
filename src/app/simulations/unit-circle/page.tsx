import { redirect } from 'next/navigation';

// The unit circle explorer now lives under Mathematics. This keeps any link
// or bookmark to the old address working.
export default function OldUnitCircleRedirect() {
  redirect('/mathematics/unit-circle');
}
