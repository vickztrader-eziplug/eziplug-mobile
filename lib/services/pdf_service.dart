import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
// ignore: depend_on_referenced_packages
import 'package:pdf/pdf.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/widgets.dart' as pw;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../screens/transactions/transactions_screen.dart';

/// True once a Unicode TTF has been embedded in the document. The built-in
/// Helvetica the pdf package falls back on is WinAnsi-encoded and has no naira
/// glyph, so amounts are labelled "NGN" instead of "₦" when the font can't be
/// loaded (offline, for example) rather than printing an empty box.
bool _unicodeFont = false;

String get _naira => _unicodeFont ? '₦' : 'NGN ';

/// Money as it should read on a receipt: grouped thousands, always two
/// decimals. Accepts the doubles from the model and the raw strings/ints that
/// come straight off the API.
String _money(dynamic value) {
  double? amount;
  if (value is num) {
    amount = value.toDouble();
  } else if (value != null) {
    amount = double.tryParse(
      value.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''),
    );
  }
  if (amount == null) return value?.toString() ?? 'N/A';

  final parts = amount.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '${amount < 0 ? '-' : ''}$_naira$whole.${parts[1]}';
}

String _formatDateTime(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
}

/// Tokens are read off the page and typed into a meter, so group them in fours
/// the way the utilities print them.
String _groupDigits(String value) {
  final compact = value.replaceAll(RegExp(r'[\s-]'), '');
  final digits = compact.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != compact.length || digits.length < 8) return value;

  final groups = <String>[];
  for (var i = 0; i < digits.length; i += 4) {
    final end = i + 4 > digits.length ? digits.length : i + 4;
    groups.add(digits.substring(i, end));
  }
  return groups.join(' ');
}

/// A single label/value line inside a receipt section.
class _Line {
  const _Line(this.label, this.value, {this.emphasis});

  final String label;
  final String value;
  final PdfColor? emphasis;
}

class PdfService {
  // Brand palette, mirroring AppColors so a shared receipt still reads as
  // Eziplug next to the app itself.
  static final PdfColor _brand = PdfColor.fromHex('#3B2FE2');
  static final PdfColor _brandDeep = PdfColor.fromHex('#2A1FB5');
  static final PdfColor _brandLight = PdfColor.fromHex('#6B5FFF');
  static final PdfColor _brandTint = PdfColor.fromHex('#F0EEFF');
  static final PdfColor _brandTintLine = PdfColor.fromHex('#CBC5FF');
  static final PdfColor _onBrandSoft = PdfColor.fromHex('#D8D4FF');
  static final PdfColor _ink = PdfColor.fromHex('#1E2230');
  static final PdfColor _inkSoft = PdfColor.fromHex('#6B7280');
  static final PdfColor _line = PdfColor.fromHex('#E6E9F0');
  static final PdfColor _surface = PdfColor.fromHex('#F7F8FC');
  static final PdfColor _green = PdfColor.fromHex('#0E9F52');

  // Fonts and the logo are resolved once per process — a receipt is often
  // shared several times in a session and neither ever changes.
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.MemoryImage? _logo;
  static bool _assetsTried = false;

  static Future<File> generateReceipt(TransactionModel transaction) async {
    await _loadAssets();

    final receipt = _ReceiptData(transaction);

    final pdf = pw.Document(
      title: 'Eziplug Receipt ${receipt.reference}',
      author: 'Eziplug',
      creator: 'Eziplug Mobile',
      subject: '${transaction.type} transaction receipt',
    );

    final theme = _regularFont != null
        ? pw.ThemeData.withFont(
            base: _regularFont!,
            bold: _boldFont ?? _regularFont!,
            italic: _regularFont!,
            boldItalic: _boldFont ?? _regularFont!,
          )
        : pw.ThemeData.base();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 22),
          theme: theme,
          buildBackground: (context) => _watermark(),
        ),
        // Long receipts (a swap with bank details, a bill with a token) flow
        // onto a second page instead of being clipped by a fixed-height Page.
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _continuationBar(receipt),
        footer: _footer,
        build: (context) => [
          _brandHeader(receipt),
          pw.SizedBox(height: 14),
          _amountHero(receipt),
          pw.SizedBox(height: 14),
          _section('Transaction Summary', receipt.summaryLines),
          if (receipt.serviceLines.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _section(receipt.serviceSectionTitle, receipt.serviceLines),
          ],
          if (receipt.token != null) ...[
            pw.SizedBox(height: 10),
            _tokenBox(receipt.tokenLabel, receipt.token!),
          ],
          pw.SizedBox(height: 12),
          _closing(),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final safeReference = receipt.reference.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${output.path}/Eziplug_Receipt_$safeReference.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static Future<void> _loadAssets() async {
    if (_assetsTried) return;
    _assetsTried = true;

    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      _logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      _logo = null; // Falls back to a lettermark badge.
    }

    try {
      // PdfGoogleFonts swallows its own network/asset failures and quietly
      // returns a plain Helvetica Font instead of throwing, so a try/catch
      // here can't detect a failed fetch — check the concrete type instead:
      // only a real TtfFont carries the naira glyph.
      final regular = await PdfGoogleFonts.robotoRegular().timeout(
        const Duration(seconds: 6),
      );
      final bold = await PdfGoogleFonts.robotoBold().timeout(
        const Duration(seconds: 6),
      );

      if (regular is pw.TtfFont && bold is pw.TtfFont) {
        _regularFont = regular;
        _boldFont = bold;
        _unicodeFont = true;
      }
    } catch (_) {
      // Leave fonts null — _closing/_naira fall back to the bundled Helvetica
      // and an "NGN" prefix instead of a missing glyph.
    }
  }

  // ---------------------------------------------------------------- chrome

  static pw.Widget _watermark() {
    final logo = _logo;
    if (logo == null) return pw.SizedBox();
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.04,
        child: pw.Image(logo, width: 360, height: 360),
      ),
    );
  }

  static pw.Widget _logoBadge({double size = 40}) {
    final logo = _logo;
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(size / 4),
      ),
      child: logo == null
          ? pw.Center(
              child: pw.Text(
                'E',
                style: pw.TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _brand,
                ),
              ),
            )
          : pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  static pw.Widget _brandHeader(_ReceiptData receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(14),
        gradient: pw.LinearGradient(
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
          colors: [_brandDeep, _brand, _brandLight],
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _logoBadge(),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Eziplug',
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'TRANSACTION RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: _onBrandSoft,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'REFERENCE',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _onBrandSoft,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                receipt.reference,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                _formatDateTime(receipt.transaction.date),
                style: pw.TextStyle(fontSize: 8, color: _onBrandSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountHero(_ReceiptData receipt) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            receipt.isCredit ? 'AMOUNT RECEIVED' : 'AMOUNT PAID',
            style: pw.TextStyle(
              fontSize: 8.5,
              color: _inkSoft,
              letterSpacing: 1.6,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${receipt.isCredit ? '+' : '-'} ${_money(receipt.transaction.amount)}',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: receipt.isCredit ? _green : _ink,
            ),
          ),
          pw.SizedBox(height: 9),
          _statusPill(receipt),
          if (receipt.headline.isNotEmpty) ...[
            pw.SizedBox(height: 9),
            pw.Text(
              receipt.headline,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, color: _inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _statusPill(_ReceiptData receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: receipt.statusBackground,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(
              color: receipt.statusColor,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            receipt.statusLabel,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: receipt.statusColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(String title, List<_Line> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 3,
              height: 11,
              decoration: pw.BoxDecoration(
                color: _brand,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            children: List.generate(lines.length, (index) {
              final line = lines[index];
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  border: index == lines.length - 1
                      ? null
                      : pw.Border(
                          bottom: pw.BorderSide(color: _line, width: 0.6),
                        ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Flexed on both sides so long values — wallet addresses,
                    // gateway references — wrap instead of overflowing.
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        line.label,
                        style: pw.TextStyle(fontSize: 9.5, color: _inkSoft),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      flex: 6,
                      child: pw.Text(
                        line.value,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: line.emphasis ?? _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  static pw.Widget _tokenBox(String label, String token) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: pw.BoxDecoration(
        color: _brandTint,
        border: pw.Border.all(color: _brandTintLine),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8.5,
              color: _brandDeep,
              letterSpacing: 1.6,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _groupDigits(token),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _closing() {
    // pw.MultiPage lays its body out with crossAxisAlignment.start, so a bare
    // Column here would shrink-wrap to its longest line and sit flush left —
    // width: double.infinity makes it fill the page so the centered text
    // actually centers on the page, not just within its own text block.
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Thank you for using Eziplug',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'This is a computer-generated receipt and does not require a signature.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8.5, color: _inkSoft),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Generated ${_formatDateTime(DateTime.now())}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: _inkSoft),
          ),
        ],
      ),
    );
  }

  static pw.Widget _continuationBar(_ReceiptData receipt) {
    final logo = _logo;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 22,
                height: 22,
                decoration: pw.BoxDecoration(
                  color: logo == null ? _brand : PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: logo == null
                    ? pw.Center(
                        child: pw.Text(
                          'E',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      )
                    : pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Eziplug Receipt',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                receipt.reference,
                style: pw.TextStyle(fontSize: 9, color: _inkSoft),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _line, thickness: 0.6, height: 1),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _line, thickness: 0.6, height: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'support@eziplug.app',
              style: pw.TextStyle(fontSize: 8, color: _inkSoft),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _inkSoft),
            ),
          ],
        ),
      ],
    );
  }
}

/// Everything the receipt prints, resolved from whichever shape the
/// transaction arrived in.
///
/// The unified transactions endpoint nests service fields under
/// `transactionable`/`metadata`, while the older per-service screens hand the
/// service record itself over as `rawData`. Flattening all three into one map
/// (service fields last, so they win over the envelope's generic `type`,
/// `amount`, `status`) is what stops receipts printing "N/A" for every field
/// when they are shared from the unified details screen.
class _ReceiptData {
  _ReceiptData(this.transaction)
      : data = <String, dynamic>{
          ...transaction.rawData,
          ...?transaction.metadata,
          ...?transaction.transactionable,
        };

  final TransactionModel transaction;
  final Map<String, dynamic> data;

  String get reference =>
      transaction.reference.isNotEmpty && transaction.reference != 'null'
          ? transaction.reference
          : 'N/A';

  /// Credit or debit. Unified payloads state it outright; the legacy screens
  /// only know the service label, so those fall back to the categories that
  /// can only ever pay into the wallet.
  bool get isCredit {
    final direction = transaction.rawData['type']?.toString().toLowerCase();
    if (direction == 'credit') return true;
    if (direction == 'debit') return false;
    return const {'payment', 'refund', 'bonus'}
        .contains(transaction.type.toLowerCase());
  }

  String get statusLabel {
    final status = transaction.status.trim();
    return status.isEmpty ? 'UNKNOWN' : status.toUpperCase();
  }

  bool get _isSuccess => const {'completed', 'success', 'successful', 'paid'}
      .contains(transaction.status.toLowerCase());

  bool get _isPending => const {'pending', 'processing', 'initiated'}
      .contains(transaction.status.toLowerCase());

  bool get _isFailed =>
      const {'failed', 'cancelled', 'canceled', 'rejected', 'reversed'}
          .contains(transaction.status.toLowerCase());

  PdfColor get statusColor {
    if (_isSuccess) return PdfColor.fromHex('#0E9F52');
    if (_isPending) return PdfColor.fromHex('#B26B00');
    if (_isFailed) return PdfColor.fromHex('#D93025');
    return PdfColor.fromHex('#5F6B7A');
  }

  PdfColor get statusBackground {
    if (_isSuccess) return PdfColor.fromHex('#E7F8EE');
    if (_isPending) return PdfColor.fromHex('#FFF4E5');
    if (_isFailed) return PdfColor.fromHex('#FDECEA');
    return PdfColor.fromHex('#EEF1F5');
  }

  /// One line under the amount saying what the transaction was, without
  /// repeating the rows below it.
  String get headline {
    final title = transaction.title.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'transaction') return title;
    return _text(['description']) ?? '';
  }

  String? _text(List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null' && text != '[]' && text != '{}') {
        return text;
      }
    }
    return null;
  }

  String? _nested(String parent, String child) {
    final value = data[parent];
    if (value is Map) {
      final inner = value[child];
      if (inner != null) {
        final text = inner.toString().trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
    }
    return null;
  }

  List<_Line> get summaryLines {
    final lines = <_Line>[
      _Line('Transaction Type', transaction.type),
      _Line('Reference', reference),
    ];

    final id = transaction.id.trim();
    if (id.isNotEmpty && id != 'null') {
      lines.add(_Line('Transaction ID', id));
    }

    lines.add(_Line('Date & Time', _formatDateTime(transaction.date)));
    lines.add(_Line('Status', statusLabel, emphasis: statusColor));

    // transaction.provider is the internal VAS/payment vendor that fulfilled
    // the transaction (vtpass, paystack, quidax, ...) — never surfaced on the
    // receipt, since that's our own backend detail, not something the
    // customer should see or that we should be advertising on their behalf.

    final recipient = transaction.recipient?.trim();
    if (recipient != null && recipient.isNotEmpty && recipient != 'null') {
      lines.add(_Line('Recipient', recipient));
    }

    return lines;
  }

  String get serviceSectionTitle {
    switch (transaction.type) {
      case 'Payment':
        return 'Payment Details';
      case 'Payout':
        return 'Payout Details';
      default:
        return 'Service Details';
    }
  }

  List<_Line> get serviceLines {
    final lines = <_Line>[];

    void add(String label, String? value, {PdfColor? emphasis}) {
      if (value == null) return;
      final text = value.trim();
      if (text.isEmpty || text == 'null') return;
      lines.add(_Line(label, text, emphasis: emphasis));
    }

    final network = _nested('network', 'name') ?? _text(['network_name']);
    final phone = _text(['phone', 'phone_number']);

    switch (transaction.type) {
      case 'Airtime':
        add('Network', network);
        add('Phone Number', phone);
        break;

      case 'Data':
        add('Network', network);
        add('Phone Number', phone);
        add(
          'Plan',
          _nested('data_price', 'plan_name') ??
              _nested('data_plan', 'plan_name') ??
              _text(['plan_name']),
        );
        add('Size', _nested('data_price', 'size') ?? _text(['size']));
        add(
          'Validity',
          _nested('data_price', 'validity') ?? _text(['validity']),
        );
        break;

      case 'Cable':
        add('Provider', _nested('cable', 'name') ?? _text(['cable_name']));
        add(
          'Plan',
          _nested('cable_plan', 'name') ??
              _text(['plan_name', 'cable_plan_name']),
        );
        add(
          'Smartcard Number',
          _text(['iuc_number', 'smartcard_number', 'account_number']),
        );
        add('Customer Name', _text(['customer_name', 'account_name']));
        break;

      case 'Bill':
        add(
          'Provider',
          _nested('bill', 'name') ?? _text(['bill_name', 'disco_name']),
        );
        add('Meter / Account Number', _text(['meter_number', 'account_number']));
        add('Meter Type', _text(['meter_type']));
        add('Customer Name', _text(['customer_name', 'account_name']));
        add('Units', _text(['units', 'unit']));
        break;

      case 'Giftcard':
        add('Card', _text(['card_type']));
        add('Card Category', _text(['type', 'category']));
        add('Quantity', _text(['quantity']) ?? '1');
        add('Card Value', data['amount'] == null ? null : _money(data['amount']));
        add('Rate', _text(['rate']));
        break;

      case 'Crypto':
        add('Coin', _nested('crypto', 'name'));
        add('Symbol', _nested('crypto', 'symbol') ?? _text(['symbol']));
        add('Wallet Address', _text(['wallet_address', 'address']));
        add('Rate', _nested('crypto', 'usd_rate') ?? _text(['rate', 'usd_rate']));
        add(
          'Naira Equivalent',
          data['naira_equivalent'] == null
              ? null
              : _money(data['naira_equivalent']),
        );
        break;

      case 'Airtime Swap':
        add('Network', network);
        add('Phone Number', phone);
        add(
          'Airtime Amount',
          data['airtime_amount'] == null
              ? null
              : _money(data['airtime_amount']),
        );
        add(
          'Cash Amount',
          data['cash_amount'] == null ? null : _money(data['cash_amount']),
        );
        final rate = _text(['conversion_rate']);
        add('Conversion Rate', rate == null ? null : '$rate%');
        add('Account Number', _text(['account_number']));
        add('Account Name', _text(['account_name']));
        add('Bank Name', _text(['bank_name', 'bank']));
        break;

      case 'Payment':
        // The payment gateway (paystack, flutterwave, ...) is our own
        // backend routing detail — never shown to the customer. The
        // reference number is kept (relabelled) since it's just an opaque
        // code useful for support, not a vendor name.
        add('Payment Method', _text(['type', 'channel'])?.toUpperCase());
        add('Payment Reference', _text(['gateway_reference']));
        add('Card Type', _text(['card_type']));
        final last4 = _text(['last4', 'last_four']);
        add('Card Number', last4 == null ? null : '**** **** **** $last4');
        add('Currency', _text(['currency']) ?? 'NGN');
        break;

      case 'User Gift':
        add('Beneficiary', _text(['recipient', 'beneficiary', 'receiver_name']));
        add('Channel', _text(['channel'])?.toUpperCase() ?? 'WALLET');
        add('Note', _text(['note', 'remark']));
        add('Currency', _text(['currency']) ?? 'NGN');
        break;

      case 'Betting':
        add(
          'Platform',
          _nested('betting', 'name') ?? _text(['bet_name', 'platform']),
        );
        add('Customer ID', _text(['customer_id', 'account_number', 'user_id']));
        add('Customer Name', _text(['customer_name', 'account_name']));
        break;

      case 'Edupin':
        add(
          'Exam',
          _nested('exam', 'name') ??
              _text(['exam_name', 'exam_type', 'service_name']),
        );
        add('Quantity', _text(['quantity']));
        break;

      case 'Payout':
        add('Bank Name', _text(['bank_name', 'bank']));
        add('Account Number', _text(['account_number']));
        add('Account Name', _text(['account_name']));
        add('Fee', data['fee'] == null ? null : _money(data['fee']));
        break;

      case 'Refund':
      case 'Bonus':
        add('Reason', _text(['reason', 'note']));
        break;
    }

    // Nothing type-specific matched (a new category, or a sparse payload) —
    // fall back to the generic fields so the section is never empty.
    if (lines.isEmpty) {
      add('Description', _text(['description']));
      add('Channel', _text(['channel'])?.toUpperCase());
      add('Currency', _text(['currency']));
    }

    return lines;
  }

  String get tokenLabel =>
      transaction.type == 'Bill' ? 'Meter Token' : 'Voucher / Pin';

  String? get token {
    final direct = _text(['token', 'purchased_code', 'pin']);
    if (direct != null) return direct;

    for (final parent in ['results', 'response', 'data']) {
      final nested = _nested(parent, 'token') ??
          _nested(parent, 'purchased_code') ??
          _nested(parent, 'pin');
      if (nested != null) return nested;
    }
    return null;
  }

}
