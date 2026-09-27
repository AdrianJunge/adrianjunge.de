import fs from "node:fs/promises";
import path from "node:path";
import lighthouse from "lighthouse";
import { launch } from "chrome-launcher";
import { validateBudgets, readMetrics, summarizeRuns, budgetViolations } from './performance_contract.mjs';
import { measureInteractions } from './interaction-performance.mjs';
import { captureVisuals } from './visual-review.mjs';

// Run only against the disposable production instance owned by production-check.
const base = new URL(process.env.PERFORMANCE_BASE_URL || "http://127.0.0.1:3000");
if (!new Set(["127.0.0.1", "localhost", "[::1]"]).has(base.hostname)) {
  throw new Error("Performance checks require a loopback production instance.");
}
const root = path.resolve(import.meta.dirname, "..");
const budgets = validateBudgets(JSON.parse(await fs.readFile(path.join(root, "config/performance-budgets.json"), "utf8")));
const reportDirectory = path.join(root, "tmp/performance");
const samples = Number(process.env.PERFORMANCE_RUNS || 3);
if (!Number.isInteger(samples) || samples < 1 || samples > 10) throw new Error("PERFORMANCE_RUNS must be between 1 and 10.");
// A failed rerun must never retain a previous successful summary or screenshots.
await fs.rm(reportDirectory, { recursive: true, force: true });
await fs.rm(path.join(root, "tmp/visual-review"), { recursive: true, force: true });
await fs.mkdir(reportDirectory, { recursive: true });

const summary = [];
for (const budget of budgets.pages) {
  const runs = [];
  for (let attempt = 0; attempt < samples; attempt += 1) {
    const chrome = await launch({ chromeFlags: ["--headless", "--no-sandbox", "--disable-dev-shm-usage"] });
    try {
      const result = await lighthouse(new URL(budget.path, base).href, {
        port: chrome.port, output: ["json", "html"], logLevel: "error",
        onlyCategories: ["performance", "accessibility"],
        formFactor: "mobile", screenEmulation: { mobile: true, width: 390, height: 844, deviceScaleFactor: 1, disabled: false },
        throttlingMethod: "simulate", disableStorageReset: false,
      });
      if (result.lhr.runtimeError) throw new Error(result.lhr.runtimeError.message);
      const prefix = `${budget.path.replace(/\W+/g, "-") || "home"}-${attempt + 1}`;
      await fs.writeFile(path.join(reportDirectory, `${prefix}.json`), result.report[0]);
      await fs.writeFile(path.join(reportDirectory, `${prefix}.html`), result.report[1]);
      runs.push(readMetrics(result.lhr));
    } finally {
      await chrome.kill();
    }
  }
  const median = summarizeRuns(runs);
  const violations = budgetViolations(median, budget.limits);
  summary.push({ path: budget.path, median, runs, violations });
  console.log(`${budget.path}: ${Math.round(median.total_bytes / 1024)} KiB, ${median.requests} requests; ${violations.length ? violations.join("; ") : "budgets passed"}`);
}
await fs.writeFile(path.join(reportDirectory, "summary.json"), JSON.stringify({ conditions: `${budgets.conditions} Median of ${samples} run(s) per page.`, samples, summary }, null, 2));
await measureInteractions(base, reportDirectory);
await captureVisuals(base);
if (summary.some((entry) => entry.violations.length)) process.exitCode = 1;
