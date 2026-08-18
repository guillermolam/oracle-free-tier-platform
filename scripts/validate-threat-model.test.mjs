#!/usr/bin/env node
// Deterministic tests for validate-threat-model.mjs. Each case writes a
// small, self-contained fixture instance file (no ARCH-* refs, so these
// don't depend on traceability.md's exact content) to an isolated temp
// directory, runs the validator as a subprocess against it via the
// THREAT_MODEL_INSTANCES_DIR/SCHEMA_PATH/TRACEABILITY_PATH env overrides,
// and asserts the exit code. Mirrors check-gpg-signing.test.sh's pattern:
// isolate, don't mock the logic under test.
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");
const VALIDATOR = join(__dirname, "validate-threat-model.mjs");
const SCHEMA_PATH = join(REPO_ROOT, "docs/03-threat-model/model/schema/threat-model.schema.json");
// Fixtures deliberately avoid ARCH-* refs, but the validator always reads
// this file — point it at the real one so 'EXTERNAL' + no ARCH-* usage
// still resolves correctly regardless of its content.
const TRACEABILITY_PATH = join(REPO_ROOT, "docs/01-architecture/traceability.md");

let PASS = 0, FAIL = 0;

const BASE_ACTOR = `
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }`;

function fixtureHeader(extra = "") {
  return `domain: network
schema_version: 2.0.0
model_version: 0.1.0
generated_from:
  - { source_type: spec, ref: "SPEC-TEST.md", status: specified }
${extra}
`;
}

function runCase(name, expectedExit, yamlContent) {
  const dir = mkdtempSync(join(tmpdir(), "threat-model-test-"));
  const instancesDir = join(dir, "instances");
  mkdirSync(instancesDir);
  writeFileSync(join(instancesDir, "network.yaml"), yamlContent);

  const result = spawnSync("node", [VALIDATOR], {
    env: {
      ...process.env,
      THREAT_MODEL_INSTANCES_DIR: instancesDir,
      THREAT_MODEL_SCHEMA_PATH: SCHEMA_PATH,
      THREAT_MODEL_TRACEABILITY_PATH: TRACEABILITY_PATH,
    },
    encoding: "utf8",
  });

  rmSync(dir, { recursive: true, force: true });

  if (result.status === expectedExit) {
    console.log(`PASS: ${name}`);
    PASS++;
  } else {
    console.error(`FAIL: ${name} (expected exit ${expectedExit}, got ${result.status})`);
    console.error(result.stdout, result.stderr);
    FAIL++;
  }
}

// 1. Valid minimal corpus -> passes.
runCase("valid minimal corpus", 0, fixtureHeader(`actors:${BASE_ACTOR}`));

// 2. Dangling ref -> fails.
runCase(
  "dangling ref",
  1,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    identity_refs: ["IDENT-DOES-NOT-EXIST"]
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }`)
);

// 3. Duplicate ID -> fails.
runCase(
  "duplicate id",
  1,
  fixtureHeader(`actors:${BASE_ACTOR}${BASE_ACTOR}`)
);

// 4. Invalid enum value -> schema failure.
runCase(
  "invalid enum value",
  1,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: not-a-real-type
    description: fixture
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }`)
);

// 5. Contradictory same_principal -> fails.
runCase(
  "contradictory same_principal",
  1,
  fixtureHeader(`identities:
  - id: IDENT-A
    name: Identity A
    system: github
    principal_type: user
    description: fixture
    maps_to:
      - { identity_ref: IDENT-B, mapping_mechanism: test, same_principal: true }
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }
  - id: IDENT-B
    name: Identity B
    system: oci-iam
    principal_type: user
    description: fixture
    maps_to:
      - { identity_ref: IDENT-A, mapping_mechanism: test, same_principal: false }
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }`)
);

// 6. Consistent same_principal (both true) -> passes.
runCase(
  "consistent same_principal",
  0,
  fixtureHeader(`identities:
  - id: IDENT-A
    name: Identity A
    system: github
    principal_type: user
    description: fixture
    maps_to:
      - { identity_ref: IDENT-B, mapping_mechanism: test, same_principal: true }
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }
  - id: IDENT-B
    name: Identity B
    system: oci-iam
    principal_type: user
    description: fixture
    maps_to:
      - { identity_ref: IDENT-A, mapping_mechanism: test, same_principal: true }
    state: specified
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: specified }`)
);

// 7. state=implemented with only planned evidence -> fails.
runCase(
  "implemented without implemented evidence",
  1,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: implemented
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: planned }`)
);

// 8. state=implemented WITH implemented evidence -> passes.
runCase(
  "implemented with implemented evidence",
  0,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: implemented
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: implemented }`)
);

// 9. state=decision-pending with no gaps[] entry -> fails.
runCase(
  "decision-pending without gap",
  1,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: decision-pending
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: decision-pending }`)
);

// 10. state=decision-pending WITH a matching gaps[] entry -> passes.
runCase(
  "decision-pending with gap",
  0,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: decision-pending
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: decision-pending }
gaps:
  - id: GAP-TEST-001
    subject_ref: ACTOR-TEST
    field: some-field
    reason: fixture reason
    blocking: false
    evidence:
      - { source_type: spec, ref: "SPEC-TEST.md", status: decision-pending }`)
);

// 11. deployed-observation evidence WITH mechanism -> passes.
runCase(
  "deployed-observation with mechanism",
  0,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: implemented
    evidence:
      - { source_type: deployed-observation, mechanism: oci-api, ref: "oci test-command, 2026-01-01", status: implemented }`)
);

// 12. deployed-observation evidence with NO mechanism -> fails.
runCase(
  "deployed-observation missing mechanism",
  1,
  fixtureHeader(`actors:
  - id: ACTOR-TEST
    name: Test actor
    actor_type: human
    description: fixture
    state: implemented
    evidence:
      - { source_type: deployed-observation, ref: "oci test-command, 2026-01-01", status: implemented }`)
);

// 13. mechanism on a non-deployed-observation source -> fails.
runCase(
  "mechanism on document source",
  1,
  fixtureHeader(`actors:${BASE_ACTOR.replace(
    '{ source_type: spec, ref: "SPEC-TEST.md", status: specified }',
    '{ source_type: spec, mechanism: oci-api, ref: "SPEC-TEST.md", status: specified }'
  )}`)
);

console.log(`\n${PASS} passed, ${FAIL} failed`);
process.exit(FAIL === 0 ? 0 : 1);
