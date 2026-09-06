import fs from "node:fs/promises";
import path from "node:path";
import lighthouse from "lighthouse";
import { launch } from "chrome-launcher";

// Run only against the disposable production instance owned by production-check.
const base = new URL(process.env.PERFORMANCE_BASE_URL || "http://127.0.0.1:3000");
if (!new Set(["127.0.0.1", "localhost", "[::1]"]).has(base.hostname)) {
  throw new Error("Performance checks require a loopback production instance.");
}
const root = path.resolve(import.meta.dirname, "..");
const budgets = JSON.parse(await fs.readFile(path.join(root, "config/performance-budgets.json"), "utf8"));
const reportDirectory = path.join(root, "tmp/performance");
await fs.mkdir(reportDirectory, { recursive: true });
const samples = Number(process.env.PERFORMANCE_RUNS || 3);
if (!Number.isInteger(samples) || samples < 1 || samples > 10) throw new Error("PERFORMANCE_RUNS must be between 1 and 10.");

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
      const resources = result.lhr.audits["resource-summary"].details.items;
      const size = (kind) => resources.find((entry) => entry.resourceType === kind)?.transferSize || 0;
      const count = resources.find((entry) => entry.resourceType === "total")?.requestCount || 0;
      runs.push({ total_bytes: size("total"), script_bytes: size("script"), stylesheet_bytes: size("stylesheet"), image_bytes: size("image"), document_bytes: size("document"), requests: count, lcp_ms: result.lhr.audits["largest-contentful-paint"].numericValue, cls: result.lhr.audits["cumulative-layout-shift"].numericValue });
    } finally {
      await chrome.kill();
    }
  }
  const median = Object.fromEntries(Object.keys(runs[0]).map((key) => [key, runs.map((run) => run[key]).sort((a, b) => a - b)[Math.floor(runs.length / 2)]]));
  const violations = Object.entries(budget.limits).filter(([key, maximum]) => median[key] > maximum).map(([key, maximum]) => `${key}: ${median[key]} > ${maximum}`);
  summary.push({ path: budget.path, median, runs, violations });
  console.log(`${budget.path}: ${Math.round(median.total_bytes / 1024)} KiB, ${median.requests} requests; ${violations.length ? violations.join("; ") : "budgets passed"}`);
}
await fs.writeFile(path.join(reportDirectory, "summary.json"), JSON.stringify({ conditions: budgets.conditions, samples, summary }, null, 2));
if (summary.some((entry) => entry.violations.length)) process.exitCode = 1;
