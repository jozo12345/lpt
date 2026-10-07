// Fetches start times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) from the London Prayer Times API
// for this month and the next 12, and writes them into data/timetables.json.
// The API key comes from the LPT_KEY environment variable (a GitHub Actions secret), never from this file.
// Run by .github/workflows/update-start-times.yml; needs Node 18+ (built-in fetch). No dependencies.
import { readFile, writeFile } from "node:fs/promises";

const KEY = process.env.LPT_KEY;
if (!KEY) throw new Error("LPT_KEY is not set. Add it under Settings → Secrets and variables → Actions.");

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

const data = JSON.parse(await readFile(FILE, "utf8"));
data.start ||= {}; data.jamaah ||= {}; data.mosques ||= [];

const now = new Date();
let changed = 0, found = [];
for (let i = 0; i <= 12; i++) {
  const dt = new Date(now.getFullYear(), now.getMonth() + i, 1);
  const key = `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}`;
  const days = await fetchMonth(dt.getFullYear(), dt.getMonth() + 1);
  if (!days.filter(Boolean).length) continue;          // not published yet
  found.push(key);
  const n = new Date(dt.getFullYear(), dt.getMonth() + 1, 0).getDate();
  const value = { days: Array.from({ length: n }, (_, d) => days[d] || [null, null, null, null, null, null]) };
  if (JSON.stringify(data.start[key]) !== JSON.stringify(value)) { data.start[key] = value; changed++; }
}
if (!found.length) throw new Error("London Prayer Times returned no times for this month. Check the key and the API.");

// Drop anything older than last month so the file stays small.
const last = new Date(now.getFullYear(), now.getMonth() - 1, 1);
const lastKey = `${last.getFullYear()}-${pad(last.getMonth() + 1)}`;
for (const k of Object.keys(data.start)) if (k < lastKey) delete data.start[k];
for (const id of Object.keys(data.jamaah)) for (const k of Object.keys(data.jamaah[id])) if (k < lastKey) delete data.jamaah[id][k];

delete data.elmChecked;
data.startChecked = now.toISOString().slice(0, 10);
if (changed) data.updated = now.toISOString();
await writeFile(FILE, JSON.stringify(data));
console.log(`Months available: ${found.join(", ")}. Updated ${changed} month(s).`);
