// Fetches start times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) from the London Prayer Times API
// for this month and the next 12, and saves them into Firebase (Firestore document public/timetables),
// then writes the whole timetable to data/timetables.json as a backup copy.
// The API key comes from the LPT_KEY environment variable and the Firebase key from FIREBASE_SERVICE_ACCOUNT
// (both GitHub Actions secrets), never from this file.
// Run by .github/workflows/update-start-times.yml; needs Node 18+ and the firebase-admin package.
// Without FIREBASE_SERVICE_ACCOUNT it only updates the backup file.
import { readFile, writeFile } from "node:fs/promises";

const KEY = process.env.LPT_KEY;
if (!KEY) throw new Error("LPT_KEY is not set. Add it under Settings → Secrets and variables → Actions.");
const SA = process.env.FIREBASE_SERVICE_ACCOUNT;

const FILE = new URL("../data/timetables.json", import.meta.url);
const pad = n => String(n).padStart(2, "0");
const hhmm = v => (typeof v === "string" && /^\d{1,2}:\d{2}$/.test(v.trim())) ? v.trim().padStart(5, "0") : null;

async function fetchMonth(year, month) {
  const url = `https://www.londonprayertimes.com/api/times/?format=json&key=${encodeURIComponent(KEY)}&year=${year}&month=${month}&24hours=true`;
  const res = await fetch(url, { headers: { "user-agent": "Salah Times community website" } });
  if (!res.ok) throw new Error(`London Prayer Times answered ${res.status} for ${year}-${pad(month)}`);
  const body = await res.json();
  const times = body && body.times ? Object.values(body.times) : [];
  const days = [];
  for (const t of times) {
    const d = /^\d{4}-\d{2}-(\d{2})$/.exec(t.date || "");
    if (!d) continue;
    days[+d[1] - 1] = [hhmm(t.fajr), hhmm(t.sunrise), hhmm(t.dhuhr), hhmm(t.asr), hhmm(t.magrib), hhmm(t.isha)];
  }
  return days;
}

// Fetch first, so nothing is changed if London Prayer Times is down.
const now = new Date();
const fetched = {};
for (let i = 0; i <= 12; i++) {
  const dt = new Date(now.getFullYear(), now.getMonth() + i, 1);
  const key = `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}`;
  const days = await fetchMonth(dt.getFullYear(), dt.getMonth() + 1);
  if (!days.filter(Boolean).length) continue;          // not published yet
  const n = new Date(dt.getFullYear(), dt.getMonth() + 1, 0).getDate();
  fetched[key] = { days: Array.from({ length: n }, (_, d) => days[d] || [null, null, null, null, null, null]) };
}
if (!Object.keys(fetched).length) throw new Error("London Prayer Times returned no times for this month. Check the key and the API.");

// Merges the new start times into a timetable object. Returns how many months changed.
function merge(data) {
  data.start ||= {}; data.jamaah ||= {}; data.mosques ||= [];
  let changed = 0;
  for (const [key, value] of Object.entries(fetched)) {
    if (JSON.stringify(data.start[key]) !== JSON.stringify(value)) { data.start[key] = value; changed++; }
  }
  // Drop anything older than last month so the data stays small.
  const last = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const lastKey = `${last.getFullYear()}-${pad(last.getMonth() + 1)}`;
  for (const k of Object.keys(data.start)) if (k < lastKey) delete data.start[k];
  for (const id of Object.keys(data.jamaah)) for (const k of Object.keys(data.jamaah[id])) if (k < lastKey) delete data.jamaah[id][k];
  delete data.elmChecked;
  data.startChecked = now.toISOString().slice(0, 10);
  if (changed) data.updated = now.toISOString();
  return changed;
}

let data, changed;
if (SA) {
  const { initializeApp, cert } = await import("firebase-admin/app");
  const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
  const db = getFirestore(initializeApp({ credential: cert(JSON.parse(SA)) }));
  const ref = db.doc("public/timetables");
  // In one step, so an admin saving jamā‘ah times at the same moment isn't overwritten.
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    // The first run moves the existing timetables (from the backup file) into Firebase.
    data = snap.exists ? JSON.parse(snap.get("json")) : JSON.parse(await readFile(FILE, "utf8"));
    changed = merge(data);
    tx.set(ref, { json: JSON.stringify(data), updated: FieldValue.serverTimestamp(), by: "weekly start-times job" });
  });
  console.log("Saved to Firebase.");
} else {
  console.log("::warning::FIREBASE_SERVICE_ACCOUNT isn't set, so only the backup file was updated.");
  data = JSON.parse(await readFile(FILE, "utf8"));
  changed = merge(data);
}
await writeFile(FILE, JSON.stringify(data));
console.log(`Months available: ${Object.keys(fetched).join(", ")}. Updated ${changed} month(s).`);
