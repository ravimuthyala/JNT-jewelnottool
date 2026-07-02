# Artist Sign-Up — Multi-Step Onboarding Prompt

```
You are working on JewelNotTool (JNT), a Flutter marketplace app.
The file artist_registration_page.dart (155KB, ~3800 lines) is a single monolithic
registration page. Refactor it into a multi-step mobile onboarding wizard styled
like Amazon's checkout flow — one focused screen per step, progress bar at top,
"Continue" CTA pinned to the bottom.

════════════════════════════════════════════
DESIGN SYSTEM
════════════════════════════════════════════
Import from: lib/theme/app_colors.dart

  Scaffold bg:   AppColors.alabaster    #F4EFE1
  Card/surface:  AppColors.snow         #FAFAF9
  Accent:        AppColors.balletSlippers #EDD9C9
  Text primary:  AppColors.blackCat     #292222
  Text muted:    AppColors.blackCatLight #6E6262
  Border:        AppColors.blackCatBorderLight #C6BDBD
  On-dark:       AppColors.white        #FFFFFF

Rules:
- Typography: Theme.of(context).textTheme only — no hardcoded sizes
- Spacing: 8px grid (8, 16, 24, 32)
- Input fields: snow bg, blackCatBorderLight border, 12px radius, 48px height
- Primary button: full-width, blackCat bg, white text, 52px height, 12px radius
- Back button: text-only, blackCatLight colour, top-left
- Progress bar: thin (4px), balletSlippers filled, blackCatBorderLight unfilled
- Section label above each field: blackCat, 13px, weight 500
- Error state: border turns red, small red hint text below field
- No Material default blue/purple anywhere

Page shell pattern:
  Scaffold(
    backgroundColor: AppColors.alabaster,
    body: SafeArea(
      child: Column(children: [
        _StepProgressBar(current: N, total: 5),
        Expanded(child: SingleChildScrollView(/* step content */)),
        _ContinueButton(onTap: _validateAndNext),
      ]),
    ),
  )

════════════════════════════════════════════
STEP SPLIT  (5 steps, each = its own Widget)
════════════════════════════════════════════

STEP 1 — Account  (2 fields only)
  Fields: email, password
  Notes:
  - Password field has show/hide toggle
  - Inline email format validation (no red until user leaves field)
  - Do NOT create the Supabase account yet — just validate + store in state

STEP 2 — Identity  (3 fields + photo)
  Fields: profile photo (avatar tap-to-upload), display name, studio name, bio
  Notes:
  - Avatar placeholder: balletSlippers circle, camera icon centre
  - Bio: 3-line max visible, 300 char counter bottom-right
  - All optional except display name

STEP 3 — Location & Services
  Fields:
    - Country dropdown (default: United States)
    - City text field
    - State (US dropdown / free text for non-US)
    - Timezone auto-detected, overridable dropdown
    - Services multi-select chips: ['Custom Press-ons', 'Nail Art', ...]
    - Min price / Max price (side by side, number inputs)
    - Rush orders toggle
  Notes:
  - Chips: selected = blackCat bg + white text; unselected = snow + blackCatBorderLight border
  - Price inputs: prefix '$', numeric keyboard

STEP 4 — Portfolio & Credentials
  Fields:
    - Nail tech type toggle: Professional / Student / Unlicensed
    - If Professional: License number, Jurisdiction (US state dropdown), Years experience dropdown
    - If Student: School name, Practice duration dropdown
    - Portfolio image upload (grid, up to 6 images)
    - Instagram handle, TikTok handle, Portfolio URL
    - Direct requests toggle (on by default)
  Notes:
  - Show/hide credential fields based on nail tech type selection
  - Image grid: 3-column, snow bg cards, + icon in empty slots
  - Social fields: prefix icons (@, @, 🔗)

STEP 5 — Payout & Terms
  Fields:
    - Payout method selector: PayPal | Venmo | Apple Pay | Bank Transfer
    - Dynamic sub-fields per method:
        PayPal → payout email
        Venmo  → @handle or phone/email
        Apple Pay → name + phone + email
        Bank  → legal name, bank name, routing number, account number
    - Checkboxes: [ ] Agree to Terms, [ ] No Copyright, [ ] Agree Safety Policy
    - Toggle: Receive product updates (default on)
  Notes:
  - Method selector: horizontal pill tabs, balletSlippers selected bg
  - All 3 checkboxes must be checked before Continue becomes active
  - Final button label: "Create My Account"

════════════════════════════════════════════
DB OPTIMIZATION (apply during extraction)
════════════════════════════════════════════
- Only call Supabase.instance.client.auth.signUp() at the END of Step 5
- Collect all field values in a single RegistrationDraft model passed between steps
- On final submit, do ONE upsert to public.artist with all fields at once
  (no partial writes mid-flow)
- Profile image: upload to Supabase Storage first, then store the URL in the upsert
- Portfolio images: batch upload, collect all URLs, store as JSON array in one write
- Mirror to Firestore with: unawaited(firestoreWrite().catchError((_) {}))
- No Firestore reads at any point during registration

════════════════════════════════════════════
FILE STRUCTURE OUTPUT
════════════════════════════════════════════
Create these files:
  lib/pages/artist_registration/
    artist_registration_flow.dart        ← shell: PageView + state holder
    step1_account.dart
    step2_identity.dart
    step3_location_services.dart
    step4_portfolio_credentials.dart
    step5_payout_terms.dart
    registration_draft.dart              ← plain Dart model, no deps
    _widgets/step_progress_bar.dart
    _widgets/continue_button.dart

Keep artist_registration_page.dart intact until all 5 steps are verified.

════════════════════════════════════════════
RULES
════════════════════════════════════════════
- Build ONE step file, then stop and ask "Ready for Step N+1?"
- Run flutter analyze after each step — fix all errors before stopping
- Never invent table/column names — check public.artist schema first
- No hardcoded colors — always use AppColors
- No StatefulWidget for steps that don't need local state — use StatelessWidget + callbacks
- Validate each step locally before allowing navigation forward
```
