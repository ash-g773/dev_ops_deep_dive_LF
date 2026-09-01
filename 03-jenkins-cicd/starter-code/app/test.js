// A deliberately tiny test. No test framework, so there's nothing
// extra to install and nothing to go wrong in the pipeline.
// In a real project this would be Jest, Vitest or Mocha.

const assert = require("assert");
const app = require("./index");

let failures = 0;

function check(name, fn) {
  try {
    fn();
    console.log(`  PASS  ${name}`);
  } catch (err) {
    console.log(`  FAIL  ${name}: ${err.message}`);
    failures++;
  }
}

console.log("Running tests...");

check("app is exported", () => {
  assert.ok(app, "app should be defined");
});

check("app has routes registered", () => {
  assert.ok(app._router, "app should have a router");
});

if (failures > 0) {
  console.log(`\n${failures} test(s) failed`);
  process.exit(1);        // NON-ZERO exit code = the pipeline will fail
}

console.log("\nAll tests passed");
process.exit(0);          // ZERO = success