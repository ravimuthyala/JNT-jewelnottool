-- Cleanup script for stray test data created by Claude during the Ambassador/NFC
-- visibility rule + order status flow debugging session (2026-07-20 to 2026-07-22).
-- Run this in the Supabase SQL Editor (service_role / postgres access required --
-- there is no DELETE RLS policy on these tables for anon/authenticated roles).
-- All rows below were verified to have a claude-*@example.com email; no production
-- or user-created rows are included.

-- 22 stray company_custom_requests rows
DELETE FROM public.company_custom_requests
WHERE id IN (
  'f0000000-0000-4000-8000-784743973845',
  'e0000000-0000-4000-8000-784743871385',
  'e0000000-0000-4000-8000-784743550136',
  'e0000000-0000-4000-8000-784743439984',
  'e0000000-0000-4000-8000-784743369926',
  'e0000000-0000-4000-8000-784743277767',
  'b0000000-0000-4000-8000-784740235894',
  'b0000000-0000-4000-8000-784740170042',
  'a0000000-0000-4000-8000-784739193790',
  'e0000000-0000-4000-8000-784743163923',
  'f0000000-0000-4000-8000-784742994315',
  'e0000000-0000-4000-8000-784742980523',
  'd0000000-0000-4000-8000-784742224419',
  'd0000000-0000-4000-8000-784742148638',
  'd0000000-0000-4000-8000-784742063512',
  'd0000000-0000-4000-8000-784741942387',
  'c0000000-0000-4000-8000-784741433444',
  'c0000000-0000-4000-8000-784741356151',
  'c0000000-0000-4000-8000-784741244940',
  'b0000000-0000-4000-8000-784740512089',
  'b0000000-0000-4000-8000-784740423784',
  'b0000000-0000-4000-8000-784740360084'
);

-- 25 stray client rows
DELETE FROM public.client
WHERE id IN (
  'c0c4d900-0237-4875-852e-7e2d4058101d',
  'a2f83a2a-6d1d-4504-bb9f-93104c81ada8',
  '9b4d9a62-145a-4d9f-8bf3-736a946b3138',
  'de0efed2-ad88-40a1-ab6d-3261616f5135',
  'acbfba15-edad-4fa8-9ce7-861ba812b466',
  '041ea9c8-1d01-4043-932d-143e2faf94a7',
  'd1a8fffd-a633-45f6-9533-3526fbdefa99',
  '771f1f48-2242-4af9-a582-6955d57fcaf7',
  '88226a03-b2b4-43a0-b32f-20c5f5fe0915',
  '67944d9b-2040-47ed-9a9d-820cd430b82e',
  'c68d6d2a-4d59-4ae8-867f-8c91778f6b48',
  '2078dc92-b5dd-44e9-84e5-0602c7a94bf5',
  'a1ce0c70-89eb-4e52-8196-d15dec64131e',
  '6d89f6ab-7a31-40b9-a711-cc803073970b',
  '304b4864-b56b-4855-b26d-ffaaa02fbcd6',
  '8a9b216d-8695-4f34-8e6f-07ba1eb820e6',
  'f1a3f5b6-843f-4876-8937-e0a6f38f7011',
  '2316994c-9b5f-478d-bbb3-c847f52b9fa4',
  'b2e84a0c-fa11-49f5-9df9-8f5a7d3892c4',
  'e2f0cfd5-3843-41f5-8501-956604e3b111',
  'e16c9ad4-a243-46eb-8b50-7c133f9413f0',
  '6e4bf3da-52e6-4eed-b4d1-a290da782c6b',
  'e79b6742-ba48-4d8e-aa74-44142d66f916',
  '705c351a-9a73-4940-8cd7-9e3091d39c0c',
  'abb50002-b337-4c97-a7e1-ff3bd579eaeb'
);

-- Optional: also remove the corresponding auth.users rows (requires service_role).
-- Uncomment if you want the throwaway test accounts fully gone, not just their
-- app-level client rows (their auth accounts will otherwise remain, unusable
-- but harmless, since nothing references them once the client row is gone).
-- DELETE FROM auth.users WHERE email LIKE 'claude-%@example.com';

-- NOTE: the block above was already run (confirmed empty as of 2026-07-22).
-- One more stray row was added afterward while visually verifying the NFC UI
-- fixes (client_campaign_details_page.dart / order_details_pages.dart) on the
-- simulator -- a single throwaway NFC-eligible request, company_email
-- cleanup-audit2-*@example.com.
DELETE FROM public.company_custom_requests
WHERE id = 'a1b2c3d4-0000-4000-8000-000000000001';
