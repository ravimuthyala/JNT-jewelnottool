/// "Order Delivered — Review & Tip" email HTML/text builder. Content and
/// layout match the reviewed design -- same table-based, inline-styled
/// markup as ShippedEmailTemplates (see shipped_email_templates.dart),
/// reusing the same palette and structure.
library;

const String _ink = '#292222';
const String _inkSoft = '#6E6262';
const String _paper = '#FAF9F9';
const String _cream = '#F4EFE1';
const String _blush = '#EDD9C9';
const String _border = '#C6BDBD';
const String _white = '#FFFFFF';

typedef EmailContent = ({String subject, String preheader, String html, String text});

class _CardRow {
  const _CardRow(this.label, this.value, {this.tabularNums = false});
  final String label;
  final String value;
  final bool tabularNums;
}

// Shared shell used by the brand/artist builders below -- mirrors
// _shellHtml/_plainText in shipped_email_templates.dart so the delivered and
// shipped emails read as one consistent family. The original `client`
// builder above predates this shell and keeps its own hand-rolled markup
// rather than being retrofit onto it.
String _shellHtml({
  required String subject,
  required String preheader,
  required String eyebrow,
  required String eyebrowBg,
  required String eyebrowFg,
  String? masthead,
  required String headline,
  required String subline,
  required List<_CardRow> cardRows,
  required String ctaLabel,
  required String ctaLink,
  String? secondaryLabel,
  String? secondaryLink,
  String? footNote,
  required String artistName,
}) {
  final secondary = secondaryLabel != null && secondaryLink != null
      ? '''
      <tr><td style="padding:14px 28px 0;">
        <a href="${_esc(secondaryLink)}" style="font:400 12.5px Arial,Helvetica,sans-serif;color:$_inkSoft;text-decoration:underline;">${_esc(secondaryLabel)}</a>
      </td></tr>'''
      : '';

  final foot = footNote != null
      ? '''
      <tr><td style="padding:14px 28px 0;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_cream;border-radius:8px;">
          <tr><td style="padding:11px 14px;font:400 11.5px Arial,Helvetica,sans-serif;color:$_inkSoft;">
            <span style="font-weight:700;color:$_ink;">For your records — </span>${_esc(footNote)}
          </td></tr>
        </table>
      </td></tr>'''
      : '';

  final mastheadHtml = masthead != null
      ? '''
      <tr><td style="padding:16px 28px 0;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border:1px solid $_border;border-radius:10px;">
          <tr><td style="padding:14px 18px;">$masthead</td></tr>
        </table>
      </td></tr>'''
      : '';

  return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(subject)}</title>
</head>
<body style="margin:0;padding:0;background:$_paper;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${_esc(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_paper;">
<tr><td align="center" style="padding:28px 14px;">
<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:$_white;border:1px solid $_border;border-radius:14px;overflow:hidden;">

<tr><td style="padding:26px 28px 0;">
  <div style="font:italic 400 20px/1 Georgia,'Times New Roman',serif;letter-spacing:0.02em;color:$_ink;">JNT</div>
</td></tr>

<tr><td style="padding:20px 28px 0;">
  <span style="display:inline-block;font:700 10px/1 Arial,Helvetica,sans-serif;letter-spacing:0.08em;text-transform:uppercase;color:$eyebrowFg;background:$eyebrowBg;padding:6px 10px;border-radius:20px;">${_esc(eyebrow)}</span>
</td></tr>
$mastheadHtml
<tr><td style="padding:16px 28px 0;">
  <div style="font:400 25px/1.28 Georgia,'Times New Roman',serif;color:$_ink;">${_esc(headline)}</div>
</td></tr>

<tr><td style="padding:10px 28px 0;">
  <div style="font:400 14px/1.6 Arial,Helvetica,sans-serif;color:$_inkSoft;max-width:460px;">${_esc(subline)}</div>
</td></tr>

<tr><td style="padding:22px 28px 0;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_cream;border-radius:10px;">
  <tr><td style="padding:16px 18px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0">${_cardRowsHtml(cardRows)}</table></td></tr>
  </table>
</td></tr>

<tr><td style="padding:22px 28px 0;">
  <table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="border-radius:8px;background:$_ink;">
    <a href="${_esc(ctaLink)}" style="display:inline-block;padding:13px 24px;font:700 13.5px Arial,Helvetica,sans-serif;color:$_paper;text-decoration:none;letter-spacing:0.01em;">${_esc(ctaLabel)}</a>
  </td></tr></table>
</td></tr>
$secondary
$foot
<tr><td style="padding:26px 28px 0;"><div style="height:1px;background:$_border;"></div></td></tr>

<tr><td style="padding:16px 28px 0;">
  <div style="font:400 12.5px/1.6 Arial,Helvetica,sans-serif;color:$_inkSoft;">Handcrafted by <span style="color:$_ink;font-weight:700;">${_esc(artistName)}</span></div>
</td></tr>

<tr><td style="padding:18px 28px 28px;">
  <div style="font:400 11.5px/1.7 Arial,Helvetica,sans-serif;color:$_inkSoft;opacity:0.85;">Questions about this order? Reply to this email or reach us at support@jntnails.com.<br>JNT &middot; Jewel Not Tool</div>
</td></tr>

</table>
</td></tr>
</table>
</body>
</html>''';
}

String _plainText({
  required String headline,
  required String subline,
  required List<_CardRow> cardRows,
  required String ctaLabel,
  required String ctaLink,
  String? secondaryLabel,
  String? secondaryLink,
  String? footNote,
  required String artistName,
}) {
  final lines = <String>[headline, '', subline, ''];
  for (final row in cardRows) {
    lines.add('${row.label.padRight(12)}${row.value}');
  }
  lines.add('');
  lines.add('$ctaLabel: $ctaLink');
  if (secondaryLabel != null && secondaryLink != null) {
    lines.add('$secondaryLabel: $secondaryLink');
  }
  if (footNote != null) {
    lines.add('');
    lines.add('For your records — $footNote');
  }
  lines.add('');
  lines.add('Handcrafted by $artistName');
  lines.add('');
  lines.add('Questions about this order? Reply to this email or reach us at support@jntnails.com.');
  lines.add('JNT · Jewel Not Tool');
  return lines.join('\n');
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _cardRowsHtml(List<_CardRow> rows) {
  final buf = StringBuffer();
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final divider = i < rows.length - 1 ? 'border-bottom:1px solid $_border;' : '';
    buf.write('''
      <tr>
        <td style="padding:9px 0;$divider font:400 13px Arial,Helvetica,sans-serif;color:$_inkSoft;width:120px;">${_esc(row.label)}</td>
        <td style="padding:9px 0;$divider font:600 13px Arial,Helvetica,sans-serif;color:$_ink;text-align:right;${row.tabularNums ? 'font-variant-numeric:tabular-nums;' : ''}">${_esc(row.value)}</td>
      </tr>''');
  }
  return buf.toString();
}

class DeliveredEmailTemplates {
  const DeliveredEmailTemplates._();

  /// Client (and client-artist-as-client) recipients: the primary requester
  /// or a group-order participant. [reviewUrl] must open directly on the
  /// Delivered order's Review & Tip screen -- see main.dart's `review-order`
  /// deep-link handling.
  static EmailContent client({
    required bool isGroupClient,
    required String recipientFirstName,
    required String primaryClientName,
    required String orderNumber,
    required String deliveredDate,
    required String artistName,
    required String reviewUrl,
    required String appLink,
  }) {
    final subject = 'Your order has arrived — rate & tip $artistName?';
    final preheader =
        'Your ${isGroupClient ? 'set' : 'nails'} are here! Leave a rating and tip for $artistName in the app.';
    final headline = isGroupClient
        ? 'Your set has arrived, $recipientFirstName!'
        : 'Your nails have arrived, $recipientFirstName!';
    final subline = isGroupClient
        ? "You're part of $primaryClientName's group order — your set from $artistName has arrived."
        : "We hope you love them. Rate $artistName and add a tip if you'd like.";

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Delivered', deliveredDate),
      _CardRow('Artist', artistName),
    ];

    final html = '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(subject)}</title>
</head>
<body style="margin:0;padding:0;background:$_paper;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${_esc(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_paper;">
<tr><td align="center" style="padding:28px 14px;">
<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:$_white;border:1px solid $_border;border-radius:14px;overflow:hidden;">

<tr><td style="padding:26px 28px 0;">
  <div style="font:italic 400 20px/1 Georgia,'Times New Roman',serif;letter-spacing:0.02em;color:$_ink;">JNT</div>
</td></tr>

<tr><td style="padding:20px 28px 0;">
  <span style="display:inline-block;font:700 10px/1 Arial,Helvetica,sans-serif;letter-spacing:0.08em;text-transform:uppercase;color:$_ink;background:$_blush;padding:6px 10px;border-radius:20px;">ORDER DELIVERED</span>
</td></tr>

<tr><td style="padding:16px 28px 0;">
  <div style="font:400 25px/1.28 Georgia,'Times New Roman',serif;color:$_ink;">${_esc(headline)}</div>
</td></tr>

<tr><td style="padding:10px 28px 0;">
  <div style="font:400 14px/1.6 Arial,Helvetica,sans-serif;color:$_inkSoft;max-width:460px;">${_esc(subline)}</div>
</td></tr>

<tr><td style="padding:22px 28px 0;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_cream;border-radius:10px;">
  <tr><td style="padding:16px 18px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0">${_cardRowsHtml(cardRows)}</table></td></tr>
  </table>
</td></tr>

<tr><td style="padding:22px 28px 0;">
  <table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="border-radius:8px;background:$_ink;">
    <a href="${_esc(reviewUrl)}" style="display:inline-block;padding:13px 24px;font:700 13.5px Arial,Helvetica,sans-serif;color:$_paper;text-decoration:none;letter-spacing:0.01em;">Rate &amp; Tip ${_esc(artistName)}</a>
  </td></tr></table>
</td></tr>

<tr><td style="padding:14px 28px 0;">
  <a href="${_esc(appLink)}" style="font:400 12.5px Arial,Helvetica,sans-serif;color:$_inkSoft;text-decoration:underline;">Or view your order in the JNT app</a>
</td></tr>

<tr><td style="padding:26px 28px 0;"><div style="height:1px;background:$_border;"></div></td></tr>

<tr><td style="padding:16px 28px 0;">
  <div style="font:400 12.5px/1.6 Arial,Helvetica,sans-serif;color:$_inkSoft;">Handcrafted by <span style="color:$_ink;font-weight:700;">${_esc(artistName)}</span></div>
</td></tr>

<tr><td style="padding:18px 28px 28px;">
  <div style="font:400 11.5px/1.7 Arial,Helvetica,sans-serif;color:$_inkSoft;opacity:0.85;">Questions about this order? Reply to this email or reach us at support@jntnails.com.<br>JNT &middot; Jewel Not Tool</div>
</td></tr>

</table>
</td></tr>
</table>
</body>
</html>''';

    final textLines = <String>[headline, '', subline, ''];
    for (final row in cardRows) {
      textLines.add('${row.label.padRight(12)}${row.value}');
    }
    textLines.add('');
    textLines.add('Rate & Tip $artistName: $reviewUrl');
    textLines.add('Or view your order in the JNT app: $appLink');
    textLines.add('');
    textLines.add('Handcrafted by $artistName');
    textLines.add('');
    textLines.add('Questions about this order? Reply to this email or reach us at support@jntnails.com.');
    textLines.add('JNT · Jewel Not Tool');

    return (subject: subject, preheader: preheader, html: html, text: textLines.join('\n'));
  }

  /// Brand contact recipient: campaign-first framing, no review/tip CTA
  /// since the brand isn't the one rating the artist. Brand requests only.
  static EmailContent brand({
    required String campaignName,
    required String brandCompanyName,
    required String primaryClientName,
    required String orderNumber,
    required String deliveredDate,
    required String artistName,
    required String appLink,
  }) {
    final subject = '$campaignName delivered — #$orderNumber';
    final preheader = "$primaryClientName's order has arrived.";
    final headline = '$campaignName has been delivered.';
    final subline =
        "$primaryClientName's order from $artistName's studio has arrived, as part of your $campaignName campaign.";

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Delivered', deliveredDate),
      _CardRow('For', primaryClientName),
    ];

    final masthead = '''
      <div style="font:700 10px Arial,Helvetica,sans-serif;letter-spacing:0.06em;text-transform:uppercase;color:$_inkSoft;">Campaign</div>
      <div style="font:italic 400 19px Georgia,'Times New Roman',serif;color:$_ink;margin-top:3px;">${_esc(campaignName)}</div>
      <div style="font:400 12px Arial,Helvetica,sans-serif;color:$_inkSoft;margin-top:2px;">${_esc(brandCompanyName)}</div>''';

    final html = _shellHtml(
      subject: subject,
      preheader: preheader,
      eyebrow: 'CAMPAIGN DELIVERED',
      eyebrowBg: _blush,
      eyebrowFg: _ink,
      masthead: masthead,
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'View Campaign in JNT',
      ctaLink: appLink,
      artistName: artistName,
    );

    final text = _plainText(
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'View Campaign in JNT',
      ctaLink: appLink,
      artistName: artistName,
    );

    return (subject: subject, preheader: preheader, html: html, text: text);
  }

  /// Artist recipient: a delivery-confirmation copy for their own records.
  static EmailContent artist({
    required bool isBrandOrder,
    required String orderNumber,
    required String deliveredDate,
    required String artistName,
    required String primaryClientName,
    required int groupClientCount,
    required String appLink,
    String campaignName = '',
    String brandCompanyName = '',
  }) {
    final subject = isBrandOrder
        ? 'Delivery confirmed — $campaignName order #$orderNumber'
        : 'Delivery confirmed — order #$orderNumber';
    final preheader = 'Marked delivered on $deliveredDate.';
    final headline = isBrandOrder
        ? 'You marked the $campaignName order as delivered.'
        : 'You marked this order as delivered.';
    const subline = "Nice work — here's a copy for your records.";

    final forText = groupClientCount > 0
        ? '$primaryClientName +$groupClientCount group'
        : primaryClientName;

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Delivered', deliveredDate),
      _CardRow('For', forText),
      if (isBrandOrder) _CardRow('Campaign', '$campaignName · $brandCompanyName'),
    ];

    final footNote = groupClientCount > 0
        ? (isBrandOrder
              ? 'Notified: $primaryClientName + $groupClientCount group members + $brandCompanyName'
              : 'Notified: $primaryClientName + $groupClientCount group members')
        : (isBrandOrder
              ? 'Notified: $primaryClientName + $brandCompanyName'
              : 'Notified: $primaryClientName');

    final html = _shellHtml(
      subject: subject,
      preheader: preheader,
      eyebrow: 'DELIVERY CONFIRMED',
      eyebrowBg: _ink,
      eyebrowFg: _cream,
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'View Order in JNT',
      ctaLink: appLink,
      footNote: footNote,
      artistName: artistName,
    );

    final text = _plainText(
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'View Order in JNT',
      ctaLink: appLink,
      footNote: footNote,
      artistName: artistName,
    );

    return (subject: subject, preheader: preheader, html: html, text: text);
  }
}
