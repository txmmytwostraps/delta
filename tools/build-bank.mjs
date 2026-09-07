// Turns the site's problem files and route-data.js into the two JSON files
// the app reads: bank/problems.json and bank/route.json.
//   node tools/build-bank.mjs <site checkout> <output dir>
import { pathToFileURL } from "node:url";
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
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
  default_course_lock: route.DEFAULT_COURSE_LOCK,
  new_per_day: route.NEW_PER_DAY,
}, null, 2) + "\n");

// Every problem, in the order the site lists them (index.json decides).
const dir = join(site, "problems");
const index = JSON.parse(readFileSync(join(dir, "index.json"), "utf8"));
const problems = index.problems.map((entry) => JSON.parse(readFileSync(join(dir, entry.id + ".json"), "utf8")));
const known = new Set(problems.map((p) => p.id));
const missing = readdirSync(dir).filter((f) => f.endsWith(".json") && f !== "index.json" && !known.has(f.replace(/\.json$/, "")));
if (missing.length) console.warn(`not in index.json, skipped: ${missing.join(", ")}`);
writeFileSync(join(out, "problems.json"), JSON.stringify({ concepts: index.concepts, problems }) + "\n");

console.log(`${out}: ${problems.length} problems, ${route.TOPICS.length} topics, ${route.MILESTONES.length} milestones`);
