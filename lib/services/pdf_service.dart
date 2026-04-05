import 'dart:io';
import 'dart:ui';
// ignore: depend_on_referenced_packages
import 'package:pdf/pdf.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/widgets.dart' as pw;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import '../screens/transactions/transactions_screen.dart';

class PdfService {
  static Future<File> generateReceipt(TransactionModel transaction) async {
    final pdf = pw.Document();

    // Define colors
    final primaryColor = PdfColor.fromHex('#3B2FE2');
    final textColor = PdfColor.fromHex('#2C3E50');
    final lightGray = PdfColor.fromHex('#ECF0F1');

    // Get status color
    Color getStatusColor(String status) {
      final statusLower = status.toLowerCase();
      if (statusLower == 'completed' ||
          statusLower == 'success' ||
          statusLower == 'successful') {
        return const Color(0xFF4CAF50); // Green
      } else if (statusLower == 'pending' || statusLower == 'processing') {
        return const Color(0xFFFF9800); // Orange
      } else if (statusLower == 'failed' ||
          statusLower == 'cancelled' ||
          statusLower == 'rejected') {
        return const Color(0xFFF44336); // Red
      }
      return const Color(0xFF9E9E9E); // Gray
    }

    final statusColor = PdfColor.fromInt(getStatusColor(transaction.status).value);

    // Determine if transaction is positive
    bool isPositive = transaction.type == 'Payment';

    // Format date
    String formatDateTime(DateTime date) {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      String hour = date.hour.toString().padLeft(2, '0');
      String minute = date.minute.toString().padLeft(2, '0');
      String second = date.second.toString().padLeft(2, '0');
      return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute:$second';
    }

    // Get transaction details
    Map<String, String> getTransactionDetails() {
      Map<String, String> details = {};
      final data = transaction.rawData;

      switch (transaction.type) {
        case 'Giftcard':
          details['Card Type'] = data['type']?.toString() ?? 'N/A';
          details['Card Name'] = data['card_type']?.toString() ?? 'N/A';
          details['Quantity'] = data['quantity']?.toString() ?? '1';
          details['Card Value'] = '₦${data['amount']?.toString() ?? '0'}';
          break;

        case 'Crypto':
          details['Coin'] = data['crypto']?['name']?.toString() ?? 'N/A';
          details['Network'] = data['crypto']?['symbol']?.toString() ?? 'N/A';
          details['Wallet Address'] = data['wallet_address']?.toString() ?? 'N/A';
          details['Crypto Amount'] = data['naira_equivalent']?.toString() ?? 'N/A';
          details['Rate'] = data['crypto']?['usd_rate']?.toString() ?? 'N/A';
          break;

        case 'Airtime':
          details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
          details['Phone Number'] = data['phone']?.toString() ?? 'N/A';
          break;

        case 'Airtime Swap':
          details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
          details['Phone Number'] = data['phone_number']?.toString() ?? 'N/A';
          details['Airtime Amount'] = '₦${data['airtime_amount']?.toString() ?? '0'}';
          details['Cash Amount'] = '₦${data['cash_amount']?.toString() ?? '0'}';
          details['Conversion Rate'] = '${data['conversion_rate']?.toString() ?? '0'}%';
          if (data['account_number'] != null && data['account_number'].toString().isNotEmpty) {
            details['Account Number'] = data['account_number']?.toString() ?? '';
            details['Account Name'] = data['account_name']?.toString() ?? 'N/A';
            details['Bank Name'] = data['bank_name']?.toString() ?? 'N/A';
          }
          break;

        case 'Bill':
          details['Provider'] = data['bill']?['name']?.toString() ?? 'N/A';
          details['Meter Number'] = data['account_number']?.toString() ?? 'N/A';
          final tokenVal = data['token'] ?? data['purchased_code'] ?? data['pin'] ?? data['results']?['token'] ?? data['results']?['purchased_code'] ?? data['data']?['purchased_code'] ?? data['data']?['token'] ?? data['data']?['pin'];
          if (tokenVal != null && tokenVal.toString().isNotEmpty) {
            details['Token'] = tokenVal.toString();
          }
          break;

        case 'Cable':
          details['Provider'] = data['cable']?['name']?.toString() ?? 'N/A';
          details['Plan'] = data['cable_plan']?['name']?.toString() ?? 'N/A';
          details['Smartcard Number'] = data['iuc_number']?.toString() ?? 'N/A';
          break;

        case 'Data':
          details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
          details['Phone Number'] = data['phone']?.toString() ?? 'N/A';
          details['Plan'] = data['data_price']?['plan_name']?.toString() ?? 'N/A';
          details['Validity'] = data['data_price']?['validity']?.toString() ?? 'N/A';
          break;

        case 'Payment':
          details['Payment Method'] = data['type']?.toString().toUpperCase() ?? 'N/A';
          details['Gateway'] = data['gateway']?.toString().toUpperCase() ?? 'N/A';
          details['Currency'] = data['currency']?.toString() ?? 'NGN';
          if (data['gateway_reference'] != null) {
            details['Gateway Reference'] = data['gateway_reference']?.toString() ?? '';
          }
          if (data['card_type'] != null && data['card_type'].toString().isNotEmpty) {
            details['Card Type'] = data['card_type']?.toString() ?? '';
            details['Last 4 Digits'] = data['last4']?.toString() ?? 'N/A';
          }
          details['Description'] = data['description']?.toString() ?? 'Wallet Funding';
          break;

        case 'User Gift':
          details['Description'] = data['description']?.toString() ?? 'Gift Transfer';
          details['Channel'] = data['channel']?.toString().toUpperCase() ?? 'WALLET';
          details['Currency'] = data['currency']?.toString() ?? 'NGN';
          break;
      }

      return details;
    }

    final transactionDetails = getTransactionDetails();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'EZIPLUG RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      transaction.type.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Amount Section
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      '${isPositive ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: isPositive ? PdfColor.fromHex('#4CAF50') : textColor,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        transaction.status.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Basic Information
              _buildPdfSection(
                'BASIC INFORMATION',
                primaryColor,
                textColor,
                [
                  {'Transaction Type': transaction.type},
                  {'Reference': transaction.reference},
                  {'Transaction ID': transaction.id},
                  {'Date & Time': formatDateTime(transaction.date)},
                  {'Status': transaction.status},
                ],
              ),

              pw.SizedBox(height: 20),

              // Transaction Details
              if (transactionDetails.isNotEmpty)
                _buildPdfSection(
                  'TRANSACTION DETAILS',
                  primaryColor,
                  textColor,
                  transactionDetails.entries
                      .map((e) => {e.key: e.value})
                      .toList(),
                ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: lightGray),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for using Eziplug!',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Support: supported@eziplug.app | Generated on ${DateTime.now().toString().split('.')[0]}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromHex('#95A5A6'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${transaction.reference}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildPdfSection(
    String title,
    PdfColor primaryColor,
    PdfColor textColor,
    List<Map<String, String>> items,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#BDC3C7')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final key = item.keys.first;
              final value = item.values.first;

              return pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: index < items.length - 1
                      ? pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColor.fromHex('#ECF0F1'),
                          ),
                        )
                      : null,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      key,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromHex('#7F8C8D'),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        value,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}