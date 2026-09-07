// Turns the site's problem files and route-data.js into the two JSON files
// the app reads: bank/problems.json and bank/route.json.
//   node tools/build-bank.mjs <site checkout> <output dir>
import { pathToFileURL } from "node:url";
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from "node:fs";
import { join } from "node:path";

const [site, out] = process.argv.slice(2);
if (!site || !out) {
  console.error("usage: node tools/build-bank.mjs <site checkout> <output dir>");
  process.exit(1);
}
mkdirSync(out, { recursive: true });

// The route, as plain data.
const route = await import(pathToFileURL(join(site, "site", "route-data.js")).href);
writeFileSync(join(out, "route.json"), JSON.stringify({
  topics: route.TOPICS,
  milestones: route.MILESTONES,
  lessons: route.LESSONS.map(([number, title]) => ({ number, title })),
  // The lessons grouped into stages for the Route (route-data.js STAGES);
  // the same five until the site's copy lands in a pinned commit.
  stages: route.STAGES || [
    { title: "First steps", from: 1, to: 7 },
    { title: "Variables and numbers", from: 8, to: 12 },
    { title: "Decisions", from: 13, to: 15 },
    { title: "Loops and lists", from: 16, to: 20 },
    { title: "Real functions", from: 21, to: 27 },
  ],
  default_course_lock: route.DEFAULT_COURSE_LOCK,
  new_per_day: route.NEW_PER_DAY,
}, null, 2) + "\n");

// The milestones: one file per milestone, joined into one list.
const mdir = join(site, "milestones");
if (existsSync(mdir)) {
  const milestones = readdirSync(mdir).filter((f) => f.endsWith(".json")).sort().map((f) => JSON.parse(readFileSync(join(mdir, f), "utf8")));
  writeFileSync(join(out, "milestones.json"), JSON.stringify(milestones) + "\n");
}

// The concept cards, as they are.
const cardsFile = join(site, "cards", "cards.json");
if (existsSync(cardsFile)) copyFileSync(cardsFile, join(out, "cards.json"));

// Every problem, in the order the site lists them (index.json decides).
const dir = join(site, "problems");
const index = JSON.parse(readFileSync(join(dir, "index.json"), "utf8"));
const problems = index.problems.map((entry) => JSON.parse(readFileSync(join(dir, entry.id + ".json"), "utf8")));
const known = new Set(problems.map((p) => p.id));
const missing = readdirSync(dir).filter((f) => f.endsWith(".json") && f !== "index.json" && !known.has(f.replace(/\.json$/, "")));
if (missing.length) console.warn(`not in index.json, skipped: ${missing.join(", ")}`);
writeFileSync(join(out, "problems.json"), JSON.stringify({ concepts: index.concepts, problems }) + "\n");

console.log(`${out}: ${problems.length} problems, ${route.TOPICS.length} topics, ${route.MILESTONES.length} milestones${existsSync(cardsFile) ? ", cards" : ""}`);
