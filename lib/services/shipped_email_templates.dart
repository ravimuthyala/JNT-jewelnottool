/// "Order Shipped" email HTML/text builders for the three recipient roles
/// (client, artist, brand). Content and layout match the reviewed design --
/// table-based markup with inline styles only (no CSS custom properties or
/// flexbox), since this has to render correctly in Outlook/Windows Mail as
/// well as Gmail and Apple Mail.
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
  const _CardRow(this.label, this.value, {this.tabularNums = false, this.wrap = false});
  final String label;
  final String value;
  final bool tabularNums;
  final bool wrap;
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
        <td style="padding:9px 0;$divider font:600 13px Arial,Helvetica,sans-serif;color:$_ink;text-align:right;${row.tabularNums ? 'font-variant-numeric:tabular-nums;' : ''}${row.wrap ? 'word-break:break-all;' : ''}">${_esc(row.value)}</td>
      </tr>''');
  }
  return buf.toString();
}

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

class ShippedEmailTemplates {
  const ShippedEmailTemplates._();

  /// Client (and client-artist-as-client) recipients: the primary requester
  /// or a group-order participant.
  static EmailContent client({
    required bool isGroupClient,
    required bool isBrandOrder,
    required String recipientFirstName,
    required String primaryClientName,
    required String orderNumber,
    required String shippedDate,
    required String carrierName,
    required String trackingNumber,
    required String trackingUrl,
    required String appLink,
    required String artistName,
    String campaignName = '',
    String brandCompanyName = '',
  }) {
    final subject = isBrandOrder
        ? 'Your $campaignName order has shipped — #$orderNumber'
        : 'Your order has shipped — #$orderNumber';
    final preheader =
        '$carrierName is on its way — track #${trackingNumber.length > 6 ? trackingNumber.substring(trackingNumber.length - 6) : trackingNumber}.';
    final headline = isGroupClient
        ? 'Your set is on the way, $recipientFirstName.'
        : 'Your nails are on the way, $recipientFirstName.';
    final subline = isGroupClient
        ? (isBrandOrder
              ? "You're part of $primaryClientName's group order for $campaignName — it just left $artistName's studio."
              : "You're part of $primaryClientName's group order — it just left $artistName's studio.")
        : (isBrandOrder
              ? 'Your $campaignName order just left $artistName\'s studio.'
              : 'Your order just left $artistName\'s studio.');

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Shipped', shippedDate),
      _CardRow('Carrier', carrierName),
      if (isBrandOrder) _CardRow('Campaign', '$campaignName · $brandCompanyName'),
      _CardRow('Tracking #', trackingNumber, tabularNums: true, wrap: true),
    ];

    final html = _shellHtml(
      subject: subject,
      preheader: preheader,
      eyebrow: 'ORDER SHIPPED',
      eyebrowBg: _blush,
      eyebrowFg: _ink,
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'Track My Package',
      ctaLink: trackingUrl,
      secondaryLabel: 'Or view full order details in the JNT app',
      secondaryLink: appLink,
      artistName: artistName,
    );

    final text = _plainText(
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'Track My Package',
      ctaLink: trackingUrl,
      secondaryLabel: 'Or view full order details in the JNT app',
      secondaryLink: appLink,
      artistName: artistName,
    );

    return (subject: subject, preheader: preheader, html: html, text: text);
  }

  /// Artist recipient: a shipment-confirmation copy for their own records.
  static EmailContent artist({
    required bool isBrandOrder,
    required String orderNumber,
    required String shippedDate,
    required String carrierName,
    required String trackingNumber,
    required String trackingUrl,
    required String appLink,
    required String artistName,
    required String primaryClientName,
    required int groupClientCount,
    String campaignName = '',
    String brandCompanyName = '',
  }) {
    final subject = isBrandOrder
        ? 'Shipment confirmed — $campaignName order #$orderNumber'
        : 'Shipment confirmed — order #$orderNumber';
    final preheader =
        'Logged with $carrierName, tracking #${trackingNumber.length > 6 ? trackingNumber.substring(trackingNumber.length - 6) : trackingNumber}.';
    final headline = isBrandOrder
        ? 'You marked the $campaignName order as shipped.'
        : 'You marked this order as shipped.';
    const subline = "Nice work — here's a copy for your records.";

    final forText = groupClientCount > 0
        ? '$primaryClientName +$groupClientCount group'
        : primaryClientName;

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Shipped', shippedDate),
      _CardRow('Carrier', carrierName),
      _CardRow('For', forText),
      if (isBrandOrder) _CardRow('Campaign', '$campaignName · $brandCompanyName'),
      _CardRow('Tracking #', trackingNumber, tabularNums: true, wrap: true),
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
      eyebrow: 'SHIPMENT CONFIRMED',
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

  /// Brand contact recipient: campaign-first framing. Brand requests only.
  static EmailContent brand({
    required String campaignName,
    required String brandCompanyName,
    required String primaryClientName,
    required String orderNumber,
    required String shippedDate,
    required String carrierName,
    required String trackingNumber,
    required String trackingUrl,
    required String appLink,
    required String artistName,
  }) {
    final subject = '$campaignName order has shipped — #$orderNumber';
    final preheader =
        '$carrierName is on its way — track #${trackingNumber.length > 6 ? trackingNumber.substring(trackingNumber.length - 6) : trackingNumber}.';
    final headline = '$campaignName has shipped.';
    final subline =
        "$primaryClientName's order just left $artistName's studio, on behalf of your $campaignName campaign.";

    final cardRows = <_CardRow>[
      _CardRow('Order', '#$orderNumber', tabularNums: true),
      _CardRow('Shipped', shippedDate),
      _CardRow('Carrier', carrierName),
      _CardRow('For', primaryClientName),
      _CardRow('Tracking #', trackingNumber, tabularNums: true, wrap: true),
    ];

    final masthead = '''
      <div style="font:700 10px Arial,Helvetica,sans-serif;letter-spacing:0.06em;text-transform:uppercase;color:$_inkSoft;">Campaign</div>
      <div style="font:italic 400 19px Georgia,'Times New Roman',serif;color:$_ink;margin-top:3px;">${_esc(campaignName)}</div>
      <div style="font:400 12px Arial,Helvetica,sans-serif;color:$_inkSoft;margin-top:2px;">${_esc(brandCompanyName)}</div>''';

    final html = _shellHtml(
      subject: subject,
      preheader: preheader,
      eyebrow: 'CAMPAIGN SHIPPED',
      eyebrowBg: _blush,
      eyebrowFg: _ink,
      masthead: masthead,
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'Track Package',
      ctaLink: trackingUrl,
      secondaryLabel: 'View campaign in JNT',
      secondaryLink: appLink,
      artistName: artistName,
    );

    final text = _plainText(
      headline: headline,
      subline: subline,
      cardRows: cardRows,
      ctaLabel: 'Track Package',
      ctaLink: trackingUrl,
      secondaryLabel: 'View campaign in JNT',
      secondaryLink: appLink,
      artistName: artistName,
    );

    return (subject: subject, preheader: preheader, html: html, text: text);
  }
}
