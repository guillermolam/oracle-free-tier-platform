#!/usr/bin/env node
// Validates every docs/03-threat-model/model/instances/*.yaml file against
// docs/03-threat-model/model/schema/threat-model.schema.json, then checks
// corpus-wide invariants beyond what JSON Schema alone can express:
//
//   1. No duplicate IDs across files.
//   2. Every *_ref field resolves to a real ID (a corpus element, a known
//      ARCH-* concept read live from traceability.md — not a separately
//      maintained copy that could drift — or the literal 'EXTERNAL').
//   3. No two identities' maps_to entries disagree about same_principal
//      for the same pair.
//   4. Every element with state=implemented has >=1 evidence entry with
//      status=implemented — an element's curated state can't outrun what
//      any of its sources actually assert.
//   5. Every element with state=decision-pending has >=1 gaps[] entry
//      whose subject_ref names it (scoped to top-level element state
//      only, not nested authn/authz-mechanism/transport state — see
//      README for why that's a deliberate v2 scope limit, not an
//      oversight).
//
// Known limitation: ref resolution (#2) checks *existence*, not *type* —
// e.g. a `trust_zone_ref` pointing at an ASSET-* id would pass this check
// even though it's semantically wrong. Schema `pattern` constraints catch
// the common case; policy.resource_refs and credential issuer_ref/
// storage_ref are intentionally NOT existence-checked, since they may
// legitimately name something outside this corpus (an OCI resource path,
// an external system) rather than another corpus element.
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

// Overridable for testing against fixture corpora (see check-gpg-signing.sh
// for the equivalent pattern used elsewhere in this repo: isolate, don't
// mock the logic under test).
const INSTANCES_DIR = process.env.THREAT_MODEL_INSTANCES_DIR || join(MODEL_DIR, "instances");
const SCHEMA_PATH = process.env.THREAT_MODEL_SCHEMA_PATH || join(MODEL_DIR, "schema/threat-model.schema.json");
const TRACEABILITY_PATH = process.env.THREAT_MODEL_TRACEABILITY_PATH || join(REPO_ROOT, "docs/01-architecture/traceability.md");

const COLLECTION_KEYS = [
  "scopes", "trust_zones", "trust_boundaries", "actors", "identities", "credentials",
  "components", "processes", "data_stores", "assets", "data_flows", "policies", "controls", "gaps",
];

// Top-level scalar fields on any collection item that must resolve to a known ID.
const REF_SCALAR_FIELDS = [
  "trust_zone_ref", "source_ref", "destination_ref", "class_ref", "traffic_class_ref",
  "parent_ref", "subject_ref", "subject_identity_ref", "scope_ref",
  "technical_owner_ref", "security_owner_ref", "data_owner_ref",
];
// Top-level array fields (of plain string refs) that must resolve.
const REF_ARRAY_FIELDS = [
  "identity_refs", "owner_refs", "asset_refs", "data_asset_refs", "crosses_boundary_refs",
  "side_a_refs", "side_b_refs", "implements_refs", "principal_refs",
];

function loadArchIds() {
  const text = readFileSync(TRACEABILITY_PATH, "utf8");
  return new Set([...text.matchAll(/`(ARCH-[A-Z0-9-]+)`/g)].map((m) => m[1]));
}

function collectionKeys(doc) {
  return COLLECTION_KEYS.filter((k) => Array.isArray(doc[k]));
}

function checkRef(file, item, label, ref, allKnownIds, errors) {
  if (ref && !allKnownIds.has(ref)) {
    errors.push(`FAILED (dangling ref) - ${file}: ${item.id}.${label} -> '${ref}' not found`);
  }
}

function checkMechanisms(file, item, fieldName, mechanisms, allKnownIds, errors) {
  if (!Array.isArray(mechanisms)) return;
  mechanisms.forEach((m, i) => {
    checkRef(file, item, `${fieldName}.mechanisms[${i}].identity_ref`, m.identity_ref, allKnownIds, errors);
    for (const ref of m.policy_refs || []) {
      checkRef(file, item, `${fieldName}.mechanisms[${i}].policy_refs[]`, ref, allKnownIds, errors);
    }
    for (const ref of m.principal_refs || []) {
      checkRef(file, item, `${fieldName}.mechanisms[${i}].principal_refs[]`, ref, allKnownIds, errors);
    }
    // authority_ref is intentionally not existence-checked: it may name an
    // ARCH-* concept, a component, or (per the schema's own description)
    // something not yet minted as a corpus element.
  });
}

async function main() {
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  const validate = ajv.compile(schema);

  const archIds = loadArchIds();
  const files = readdirSync(INSTANCES_DIR).filter((f) => f.endsWith(".yaml") || f.endsWith(".yml"));

  if (files.length === 0) {
    console.error(`ERROR - no instance files found under ${INSTANCES_DIR}`);
    process.exit(1);
  }

  const errors = [];
  const idOwner = new Map(); // id -> file it was first seen in
  const idToItem = new Map(); // id -> item, for the same_principal/state checks
  const allKnownIds = new Set(["EXTERNAL", ...archIds]);
  const perFileDocs = [];

  // Pass 1: schema validation + collect all IDs.
  for (const file of files) {
    const path = join(INSTANCES_DIR, file);
    const doc = load(readFileSync(path, "utf8"));
    perFileDocs.push({ file, doc });

    const ok = validate(doc);
    if (!ok) {
      errors.push(`FAILED (schema) - ${file}`);
      for (const err of validate.errors) {
        errors.push(`  ${err.instancePath || "(root)"} ${err.message}`);
      }
      continue;
    }

    for (const key of collectionKeys(doc)) {
      for (const item of doc[key]) {
        if (idOwner.has(item.id)) {
          errors.push(`FAILED (duplicate id) - ${item.id} in ${file} already defined in ${idOwner.get(item.id)}`);
        } else {
          idOwner.set(item.id, file);
          idToItem.set(item.id, item);
          allKnownIds.add(item.id);
        }
      }
    }
    console.log(`PASS (schema) - ${file}`);
  }

  if (errors.length > 0) {
    console.error(errors.join("\n"));
    console.error("\nSchema/duplicate-id errors found — skipping remaining checks.");
    process.exit(1);
  }

  // Pass 2: referential integrity, now that allKnownIds is complete across every file.
  for (const { file, doc } of perFileDocs) {
    for (const key of collectionKeys(doc)) {
      for (const item of doc[key]) {
        for (const field of REF_SCALAR_FIELDS) {
          checkRef(file, item, field, item[field], allKnownIds, errors);
        }
        for (const field of REF_ARRAY_FIELDS) {
          for (const ref of item[field] || []) checkRef(file, item, `${field}[]`, ref, allKnownIds, errors);
        }
        for (const entry of item.maps_to || []) {
          checkRef(file, item, "maps_to[].identity_ref", entry.identity_ref, allKnownIds, errors);
        }
        if (item.authentication) checkMechanisms(file, item, "authentication", item.authentication.mechanisms, allKnownIds, errors);
        if (item.authorization) checkMechanisms(file, item, "authorization", item.authorization.mechanisms, allKnownIds, errors);
      }
    }
  }

  // Pass 3: same_principal consistency — if A says (B, same_principal=X) and
  // B also says (A, same_principal=Y), X must equal Y.
  for (const { file, doc } of perFileDocs) {
    for (const identity of doc.identities || []) {
      for (const entry of identity.maps_to || []) {
        const target = idToItem.get(entry.identity_ref);
        if (!target || !Array.isArray(target.maps_to)) continue;
        const reverse = target.maps_to.find((e) => e.identity_ref === identity.id);
        if (reverse && reverse.same_principal !== entry.same_principal) {
          errors.push(
            `FAILED (contradictory same_principal) - ${file}: ${identity.id} says same_principal=${entry.same_principal} ` +
              `for ${entry.identity_ref}, but ${entry.identity_ref} says same_principal=${reverse.same_principal} for ${identity.id}`
          );
        }
      }
    }
  }

  // Pass 4: state=implemented requires >=1 evidence entry with status=implemented.
  for (const { file, doc } of perFileDocs) {
    for (const key of collectionKeys(doc)) {
      for (const item of doc[key]) {
        if (item.state === "implemented") {
          const hasImplementedEvidence = (item.evidence || []).some((e) => e.status === "implemented");
          if (!hasImplementedEvidence) {
            errors.push(`FAILED (unsupported implemented) - ${file}: ${item.id} has state=implemented but no evidence entry has status=implemented`);
          }
        }
      }
    }
  }

  // Pass 5: state=decision-pending requires a gaps[] entry naming this element.
  const gapSubjects = new Set();
  for (const { doc } of perFileDocs) {
    for (const gap of doc.gaps || []) gapSubjects.add(gap.subject_ref);
  }
  for (const { file, doc } of perFileDocs) {
    for (const key of collectionKeys(doc)) {
      if (key === "gaps") continue;
      for (const item of doc[key]) {
        if (item.state === "decision-pending" && !gapSubjects.has(item.id)) {
          errors.push(`FAILED (undocumented decision-pending) - ${file}: ${item.id} has state=decision-pending but no gaps[] entry has subject_ref='${item.id}'`);
        }
      }
    }
  }

  if (errors.length > 0) {
    console.error(errors.join("\n"));
    process.exit(1);
  }

  console.log(`\nAll ${files.length} instance file(s) valid. ${idOwner.size} corpus IDs, all invariants hold.`);
}

main();
