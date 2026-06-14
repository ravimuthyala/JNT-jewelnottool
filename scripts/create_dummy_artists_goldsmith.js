#!/usr/bin/env node

/**
 * Seed 3 dummy artist docs with Goldsmith sponsorship test data.
 *
 * Usage:
 *   node scripts/create_dummy_artists_goldsmith.js --service-account /path/to/serviceAccount.json
 *   node scripts/create_dummy_artists_goldsmith.js --service-account /path/to/serviceAccount.json --apply
 *
 * Defaults to dry-run unless --apply is provided.
 */

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {
    serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    apply: false,
    collection: 'artist',
    verbose: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--apply') args.apply = true;
    else if (token === '--verbose') args.verbose = true;
    else if (token === '--service-account') args.serviceAccount = argv[++i] || '';
    else if (token === '--collection') args.collection = argv[++i] || 'artist';
    else if (token === '--help' || token === '-h') args.help = true;
  }

  return args;
}

function printHelp() {
  console.log(`
Usage:
  node scripts/create_dummy_artists_goldsmith.js --service-account <path> [options]

Options:
  --apply                 Write to Firestore. Without this flag it is dry-run.
  --collection <name>     Target artist collection (default: artist).
  --verbose               Print per-document details.
  -h, --help              Show this help.
`);
}

function buildDummyArtists(admin) {
  const now = admin.firestore.FieldValue.serverTimestamp();

  return [
    {
      id: 'dummy_artist_goldsmith_01',
      email: 'dummy.artist.goldsmith.01@jnt.test',
      name: 'Avery Stone',
      city: 'Dallas, TX',
      points: 1325,
      completedOrders: 34,
      fiveStarReviews: 26,
      portfolioUploads: 18,
      sponsorshipTier: 'Goldsmith',
      sponsorshipStatus: 'requested',
      sponsorshipRequestedAt: now,
      createdAt: now,
      updatedAt: now,
      accountType: 'artist',
      roles: { client: false, artist: true, company: false },
      profile: {
        name: 'Avery Stone',
        displayName: 'Avery Stone',
        location: 'Dallas, TX',
        nailTechType: 'Licensed Tech',
      },
      ascension: {
        points: 1325,
        levelName: 'Goldsmith',
        label: 'Goldsmith',
        tier: 'Goldsmith',
        sponsorshipEligible: true,
      },
      sponsorshipRequest: {
        tier: 'Goldsmith',
        status: 'requested',
        requestedAt: now,
      },
      panel_ascensionPoints: 1325,
      panel_ascensionLevel: 'Goldsmith',
    },
    {
      id: 'dummy_artist_goldsmith_02',
      email: 'dummy.artist.goldsmith.02@jnt.test',
      name: 'Nora Vale',
      city: 'Houston, TX',
      points: 1780,
      completedOrders: 47,
      fiveStarReviews: 31,
      portfolioUploads: 22,
      sponsorshipTier: 'Goldsmith',
      sponsorshipStatus: 'requested',
      sponsorshipRequestedAt: now,
      createdAt: now,
      updatedAt: now,
      accountType: 'artist',
      roles: { client: false, artist: true, company: false },
      profile: {
        name: 'Nora Vale',
        displayName: 'Nora Vale',
        location: 'Houston, TX',
        nailTechType: 'Licensed Tech',
      },
      ascension: {
        points: 1780,
        levelName: 'Goldsmith',
        label: 'Goldsmith',
        tier: 'Goldsmith',
        sponsorshipEligible: true,
      },
      sponsorshipRequest: {
        tier: 'Goldsmith',
        status: 'requested',
        requestedAt: now,
      },
      panel_ascensionPoints: 1780,
      panel_ascensionLevel: 'Goldsmith',
    },
    {
      id: 'dummy_artist_goldsmith_03',
      email: 'dummy.artist.goldsmith.03@jnt.test',
      name: 'Mila Hart',
      city: 'Austin, TX',
      points: 2210,
      completedOrders: 59,
      fiveStarReviews: 42,
      portfolioUploads: 29,
      sponsorshipTier: 'Goldsmith',
      sponsorshipStatus: 'requested',
      sponsorshipRequestedAt: now,
      createdAt: now,
      updatedAt: now,
      accountType: 'artist',
      roles: { client: false, artist: true, company: false },
      profile: {
        name: 'Mila Hart',
        displayName: 'Mila Hart',
        location: 'Austin, TX',
        nailTechType: 'Licensed Tech',
      },
      ascension: {
        points: 2210,
        levelName: 'Goldsmith',
        label: 'Goldsmith',
        tier: 'Goldsmith',
        sponsorshipEligible: true,
      },
      sponsorshipRequest: {
        tier: 'Goldsmith',
        status: 'requested',
        requestedAt: now,
      },
      panel_ascensionPoints: 2210,
      panel_ascensionLevel: 'Goldsmith',
    },
  ];
}

async function main() {
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

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const admin = require('firebase-admin');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  const projectId =
    serviceAccount.project_id || process.env.GCLOUD_PROJECT || 'unknown-project';

  const db = admin.firestore();
  const auth = admin.auth();
  const seedArtists = buildDummyArtists(admin);
  const defaultPassword = 'Passw0rd@';

  console.log(
    `[${args.apply ? 'APPLY' : 'DRY-RUN'}] Preparing ${seedArtists.length} dummy artists for collection "${args.collection}"...`,
  );
  console.log(`- Firebase project: ${projectId}`);

  let created = 0;
  let authUpserted = 0;
  for (const artist of seedArtists) {
    const { id, ...payload } = artist;
    const ref = db.collection(args.collection).doc(id);

    if (args.apply) {
      await ref.set(payload, { merge: true });
      created += 1;
      try {
        const existing = await auth.getUserByEmail(payload.email);
        await auth.updateUser(existing.uid, {
          password: defaultPassword,
          displayName: payload.name,
          disabled: false,
        });
      } catch (_) {
        await auth.createUser({
          email: payload.email,
          password: defaultPassword,
          displayName: payload.name,
          disabled: false,
        });
      }
      authUpserted += 1;
      if (args.verbose) {
        console.log(
          `UPSERT ${args.collection}/${id} (${payload.email}) + AUTH USER`,
        );
      }
    } else if (args.verbose) {
      console.log(
        `WOULD UPSERT ${args.collection}/${id} (${payload.email}) + AUTH USER`,
      );
    }
  }

  console.log(`- ${args.apply ? 'Upserted' : 'Would upsert'}: ${args.apply ? created : seedArtists.length}`);
  console.log(
    `- ${args.apply ? 'Auth users upserted' : 'Would upsert auth users'}: ${args.apply ? authUpserted : seedArtists.length}`,
  );
  console.log(`- Default password: ${defaultPassword}`);
  console.log('- Tier set to Goldsmith in both ascension.tier and sponsorshipRequest.tier');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
