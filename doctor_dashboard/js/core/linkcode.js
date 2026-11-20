// Patient link codes. Pure functions (no DOM, no storage), so they can be unit-tested.
//
// One code per patient: the doctor creates it at the clinic for one specific patient; it is single-use (once a
// Patient App account redeems it, it is bound to that account) and has no expiry. The backend will generate and
// store the real codes; makeLinkCode is used in mock mode and by the tests.

// Alphabet without look-alike characters: no 0/O and no 1/I/L (31 characters)
export const ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
export const LINK_CODE_LEN = 10;   // random characters per code (31^10 ≈ 8 × 10^14 possible codes)
// Strict format of generated codes: DMS-XXXX-XXXX-XX
export const LINK_CODE_FORMAT = /^DMS-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{2}$/;
// Checked before any QR code is drawn (also accepts a backend code in another layout): capital letters, digits
// and dashes only, so names, IDs or medical data can never be put in the QR
export const LINK_CODE_RE = /^[A-Z0-9-]{4,32}$/;

const cryptoRandom = n => globalThis.crypto.getRandomValues(new Uint8Array(n));
// Rejection sampling: bytes from LIMIT up are skipped so every character is equally likely (256 % 31 ≠ 0)
const LIMIT = 256 - (256 % ALPHABET.length);

// rand(n) → n random bytes (default crypto.getRandomValues). existing: codes already in use; a collision is drawn again
export function makeLinkCode(rand = cryptoRandom, existing = []) {
  const taken = new Set(existing);
  for (let tries = 0; tries < 100; tries++) {
    let s = '';
    while (s.length < LINK_CODE_LEN) for (const b of rand(16)) if (b < LIMIT && s.length < LINK_CODE_LEN) s += ALPHABET[b % ALPHABET.length];
    const code = `DMS-${s.slice(0, 4)}-${s.slice(4, 8)}-${s.slice(8)}`;
    if (!taken.has(code)) return code;
  }
  throw new Error('link code: could not create a unique code');
}
