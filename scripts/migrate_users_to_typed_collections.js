#!/usr/bin/env node

/**
 * One-time migration:
 *   users/{uid} -> client/{uid} | artist/{uid} | client_artist/{uid} | company/{uid}
 *
 * Defaults to dry run.
 *
 * Usage:
 *   node scripts/migrate_users_to_typed_collections.js --service-account /path/to/serviceAccount.json
 *   node scripts/migrate_users_to_typed_collections.js --service-account /path/to/serviceAccount.json --apply
 *   node scripts/migrate_users_to_typed_collections.js --service-account /path/to/serviceAccount.json --apply --delete-source
 */

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {
    serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    apply: false,
    deleteSource: false,
    overwrite: false,
    sourceCollection: 'users',
    verbose: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--apply') args.apply = true;
    else if (token === '--delete-source') args.deleteSource = true;
    else if (token === '--overwrite') args.overwrite = true;
    else if (token === '--verbose') args.verbose = true;
    else if (token === '--service-account') args.serviceAccount = argv[++i] || '';
    else if (token === '--source-collection') args.sourceCollection = argv[++i] || 'users';
    else if (token === '--help' || token === '-h') args.help = true;
  }

  return args;
}

function printHelp() {
  console.log(`
Usage:
  node scripts/migrate_users_to_typed_collections.js --service-account <path> [options]

Options:
  --apply                Write to Firestore. Without this flag it is dry-run.
  --delete-source        Delete migrated docs from source collection (requires --apply).
  --overwrite            Overwrite destination doc if it already exists.
  --source-collection    Source collection name (default: users).
  --verbose              Print per-document details.
  -h, --help             Show this help.
`);
}

function resolveTargetCollection(data) {
  const roles = data && typeof data.roles === 'object' ? data.roles : {};
  const isClient = roles.client === true;
  const isArtist = roles.artist === true;
  const isCompany = roles.company === true;

  if (isClient && isArtist) return 'client_artist';
  if (isClient) return 'client';
  if (isArtist) return 'artist';
  if (isCompany) return 'company';

  const accountType = (data.accountType || '').toString().trim().toLowerCase();
  if (accountType === 'client') return 'client';
  if (accountType === 'artist') return 'artist';
  if (accountType === 'company') return 'company';
  if (accountType === 'client+artist' || accountType === 'client_artist') return 'client_artist';

  return null;
}

function normalizeAccountType(collectionName) {
  if (collectionName === 'client_artist') return 'client+artist';
  return collectionName;
}

async function main() {
  let admin;
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    process.exit(0);
  }

  if (!args.serviceAccount) {
    console.error(
      'Missing service account. Pass --service-account /path/to/serviceAccount.json or set GOOGLE_APPLICATION_CREDENTIALS.',
    );
    process.exit(1);
  }

  const serviceAccountPath = path.resolve(args.serviceAccount);
  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found: ${serviceAccountPath}`);
    process.exit(1);
  }

  if (args.deleteSource && !args.apply) {
    console.error('--delete-source requires --apply.');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  admin = require('firebase-admin');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();
  const source = db.collection(args.sourceCollection);
  const snapshot = await source.get();

  let total = 0;
  let migrated = 0;
  let skippedNoRole = 0;
  let skippedExisting = 0;
  let deleted = 0;
  let failures = 0;

  const perTarget = {
    client: 0,
    artist: 0,
    client_artist: 0,
    company: 0,
  };

  console.log(
    `[${args.apply ? 'APPLY' : 'DRY-RUN'}] Scanning ${snapshot.size} docs from "${args.sourceCollection}"...`,
  );

  for (const doc of snapshot.docs) {
    total += 1;
    const data = doc.data() || {};
    const targetCollection = resolveTargetCollection(data);

    if (!targetCollection) {
      skippedNoRole += 1;
      if (args.verbose) {
        console.log(`SKIP ${doc.id}: cannot infer account type from roles/accountType`);
      }
      continue;
    }

    const targetRef = db.collection(targetCollection).doc(doc.id);

    if (!args.overwrite) {
      const targetSnap = await targetRef.get();
      if (targetSnap.exists) {
        skippedExisting += 1;
        if (args.verbose) {
          console.log(`SKIP ${doc.id}: destination exists in "${targetCollection}"`);
        }
        continue;
      }
    }

    const payload = {
      ...data,
      accountType: normalizeAccountType(targetCollection),
      migration: {
        migratedFrom: args.sourceCollection,
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (args.apply) {
      try {
        await targetRef.set(payload, { merge: true });
        perTarget[targetCollection] += 1;
        migrated += 1;

        if (args.deleteSource) {
          await source.doc(doc.id).delete();
          deleted += 1;
        }
      } catch (err) {
        failures += 1;
        console.error(`FAIL ${doc.id}: ${err.message || err}`);
      }
    } else {
      perTarget[targetCollection] += 1;
      migrated += 1;
    }

    if (args.verbose) {
      console.log(`${args.apply ? 'MIGRATED' : 'WOULD MIGRATE'} ${doc.id} -> ${targetCollection}`);
    }
  }

  console.log('\nSummary');
  console.log(`- Total scanned: ${total}`);
  console.log(`- ${args.apply ? 'Migrated' : 'Would migrate'}: ${migrated}`);
  console.log(`- Skipped (no role/accountType): ${skippedNoRole}`);
  console.log(`- Skipped (destination exists): ${skippedExisting}`);
  console.log(`- Failures: ${failures}`);
  if (args.apply && args.deleteSource) {
    console.log(`- Deleted from "${args.sourceCollection}": ${deleted}`);
  }
  console.log(`- To client: ${perTarget.client}`);
  console.log(`- To artist: ${perTarget.artist}`);
  console.log(`- To client_artist: ${perTarget.client_artist}`);
  console.log(`- To company: ${perTarget.company}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
