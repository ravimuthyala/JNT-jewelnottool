import 'dart:typed_data';
import '_widgets/reg_helpers.dart';

class RegistrationDraft {
  // ── Step 1 · Account Credentials ──────────────────────────────────────────
  String email = '';
  String password = '';
  String phone = '';
  String phoneAreaCode = '+1';

  // ── Step 1 · Artist Profile ────────────────────────────────────────────────
  Uint8List? profileBytes;
  String studioName = '';
  String displayName = '';
  String languageSpoken = '';
  String currency = 'US Dollar (USD)';
  String bio = '';

  // ── Step 2 · Location & Service Area ──────────────────────────────────────
  String city = '';
  String country = 'United States';
  String? state;
  String manualState = '';
  String timeZone = 'America/New_York';

  // ── Step 2 · Address Information ──────────────────────────────────────────
  String addressLine1 = '';
  String addressLine2 = '';
  String addressCity = '';
  String zip = '';

  // ── Step 3 · Specialization & Pricing ────────────────────────────────────
  Set<String> services = {};
  String minPrice = '15';
  String maxPrice = '5000';
  bool rush = false;

  // ── Step 3 · Year Calendar ────────────────────────────────────────────────
  bool directRequestsEnabled = true;
  bool nfcRequestEnabled = true;
  int directRequestYear = DateTime.now().year;
  Set<DateTime> blockedDates = {};

  // ── Step 3 · Portfolio ────────────────────────────────────────────────────
  List<Uint8List> portfolioImages = [];
  String projectNotes = '';
  String instagram = '';
  String tiktok = '';

  // ── Step 4 · Credentials ─────────────────────────────────────────────────
  NailTechType nailTechType = NailTechType.professional;
  String licenseNumber = '';
  String? jurisdiction;
  String? proYearsExp;
  String school = '';
  String? practiceDuration;

  // ── Step 4 · Payment Method ──────────────────────────────────────────────
  String paymentMethod = 'PayPal';
  String paypalEmail = '';
  String venmoHandle = '';
  String applePayPaymentName = '';
  String applePayPaymentPhone = '';
  String applePayPaymentEmail = '';
  String cardName = '';
  String cardNumber = '';
  String cardExpiry = '';
  String cardCvv = '';
  String cardZip = '';
  bool paymentSaved = false;

  // ── Step 4 · Nail Material Bundles ───────────────────────────────────────
  String selectedBundle = 'Starter';
  bool bundlePurchased = false;

  // ── Step 4 · Payout ──────────────────────────────────────────────────────
  PayoutMethod payoutMethod = PayoutMethod.paypal;
  String legalName = '';
  String payoutEmail = '';
  String bankName = '';
  String routing = '';
  String accountNumber = '';
  String applePayName = '';
  String applePayPhone = '';
  String applePayEmail = '';

  // ── Step 4 · Policies & Agreements ──────────────────────────────────────
  bool agreeTerms = false;
  bool noCopyright = false;
  bool agreeSafety = false;
  bool receiveUpdates = true;
}
