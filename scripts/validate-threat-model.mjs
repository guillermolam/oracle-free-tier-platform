#!/usr/bin/env node
// Validates every docs/03-threat-model/model/instances/*.yaml file against
// docs/03-threat-model/model/schema/threat-model.schema.json, then checks
// corpus-wide referential integrity: no duplicate IDs across files, and
// every *_ref field resolves to a real ID (a corpus element, a known
// ARCH-* concept from traceability.md, or the literal 'EXTERNAL').
//
// Known limitation: ref resolution checks *existence*, not *type* —
// e.g. a `trust_zone_ref` pointing at an ASSET-* id would pass this check
// even though it's semantically wrong. Schema `pattern` constraints catch
// the common case (most ref fields are typed by ID prefix); the free-form
// ref fields (trust_zone_ref, source_ref, destination_ref, owner_refs,
// separates) are existence-checked only.
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

let Ajv2020, load;
try {
  ({ default: Ajv2020 } = await import("ajv/dist/2020.js"));
  ({ load } = await import("js-yaml"));
} catch {
  console.error("ERROR - ajv/js-yaml not installed. Run: npm ci");
  process.exit(1);
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");
const MODEL_DIR = join(REPO_ROOT, "docs/03-threat-model/model");
const INSTANCES_DIR = join(MODEL_DIR, "instances");
const SCHEMA_PATH = join(MODEL_DIR, "schema/threat-model.schema.json");
const TRACEABILITY_PATH = join(REPO_ROOT, "docs/01-architecture/traceability.md");

const REF_ARRAY_FIELDS = [
  "identity_refs", "maps_to", "owner_refs", "asset_refs",
  "data_asset_refs", "crosses_boundary_refs", "separates",
];
const REF_SCALAR_FIELDS = ["trust_zone_ref", "source_ref", "destination_ref", "class_ref", "traffic_class_ref"];

function loadArchIds() {
  const text = readFileSync(TRACEABILITY_PATH, "utf8");
  return new Set([...text.matchAll(/`(ARCH-[A-Z0-9-]+)`/g)].map((m) => m[1]));
}

function collectionKeys(doc) {
  return ["trust_zones", "trust_boundaries", "actors", "identities", "processes", "data_stores", "assets", "data_flows"]
    .filter((k) => Array.isArray(doc[k]));
}

function main() {
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  const validate = ajv.compile(schema);

  const archIds = loadArchIds();
  const files = readdirSync(INSTANCES_DIR).filter((f) => f.endsWith(".yaml") || f.endsWith(".yml"));

  if (files.length === 0) {
    console.error(`ERROR - no instance files found under ${INSTANCES_DIR}`);
    process.exit(1);
  }

  let failed = false;
  const idOwner = new Map(); // id -> file it was first seen in
  const allKnownIds = new Set(["EXTERNAL", ...archIds]);
  const perFileDocs = [];

  // Pass 1: schema validation + collect all IDs.
  for (const file of files) {
    const path = join(INSTANCES_DIR, file);
    const doc = load(readFileSync(path, "utf8"));
    perFileDocs.push({ file, doc });

    const ok = validate(doc);
    if (!ok) {
      failed = true;
      console.error(`FAILED (schema) - ${file}`);
      for (const err of validate.errors) {
        console.error(`  ${err.instancePath || "(root)"} ${err.message}`);
      }
      continue;
    }

    for (const key of collectionKeys(doc)) {
      for (const item of doc[key]) {
        if (idOwner.has(item.id)) {
          failed = true;
          console.error(`FAILED (duplicate id) - ${item.id} in ${file} already defined in ${idOwner.get(item.id)}`);
        } else {
          idOwner.set(item.id, file);
          allKnownIds.add(item.id);
        }
      }
    }
    console.log(`PASS (schema) - ${file}`);
  }

  if (failed) {
    console.error("\nSchema/duplicate-id errors found — skipping referential-integrity pass.");
    process.exit(1);
  }

  // Pass 2: referential integrity, now that allKnownIds is complete across every file.
  for (const { file, doc } of perFileDocs) {
    for (const key of collectionKeys(doc)) {
      for (const item of doc[key]) {
        for (const field of REF_SCALAR_FIELDS) {
          const val = item[field];
          if (val && !allKnownIds.has(val)) {
            failed = true;
            console.error(`FAILED (dangling ref) - ${file}: ${item.id}.${field} -> '${val}' not found`);
          }
        }
        for (const field of REF_ARRAY_FIELDS) {
          const arr = item[field];
          if (!Array.isArray(arr)) continue;
          for (const entry of arr) {
            const ref = typeof entry === "string" ? entry : entry.identity_ref;
            if (ref && !allKnownIds.has(ref)) {
              failed = true;
              console.error(`FAILED (dangling ref) - ${file}: ${item.id}.${field}[] -> '${ref}' not found`);
            }
          }
        }
      }
    }
  }

  if (failed) {
    console.error("\nReferential-integrity errors found.");
    process.exit(1);
  }

  console.log(`\nAll ${files.length} instance file(s) valid. ${idOwner.size} corpus IDs, all references resolve.`);
}

main();
