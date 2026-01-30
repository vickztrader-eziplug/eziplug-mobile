import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../services/transaction_service.dart';
import '../../services/pdf_service.dart';
import 'transactions_screen.dart'; // For PdfService compatibility

/// Unified Transaction Detail Screen using UnifiedTransaction model
class TransactionDetailUnifiedScreen extends StatelessWidget {
  final UnifiedTransaction transaction;

  const TransactionDetailUnifiedScreen({super.key, required this.transaction});

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'success' || statusLower == 'completed' || statusLower == 'successful') {
      return Colors.green;
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      return Colors.orange;
    } else if (statusLower == 'failed' || statusLower == 'cancelled' || statusLower == 'rejected') {
      return Colors.red;
    } else if (statusLower == 'reversed') {
      return Colors.purple;
    }
    return Colors.grey;
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'giftcard':
        return Colors.purple;
      case 'crypto':
        return Colors.orange;
      case 'airtime':
        return Colors.blue;
      case 'airtime_swap':
        return Colors.teal;
      case 'bill':
        return Colors.yellow.shade700;
      case 'cable':
        return Colors.indigo;
      case 'data':
        return Colors.green;
      case 'wallet_funding':
        return Colors.blueAccent;
      case 'wallet_transfer':
        return Colors.pink;
      case 'betting':
        return Colors.red;
      case 'edupin':
        return Colors.brown;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'giftcard':
        return Icons.card_giftcard;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'airtime':
        return Icons.phone_android;
      case 'airtime_swap':
        return Icons.swap_horiz;
      case 'bill':
        return Icons.lightbulb_outline;
      case 'cable':
        return Icons.tv;
      case 'data':
        return Icons.wifi;
      case 'wallet_funding':
        return Icons.payment;
      case 'wallet_transfer':
        return Icons.card_giftcard;
      case 'betting':
        return Icons.sports_soccer;
      case 'edupin':
        return Icons.school;
      case 'payout':
        return Icons.money;
      default:
        return Icons.receipt;
    }
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    int hour = date.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    String minute = date.minute.toString().padLeft(2, '0');
    String second = date.second.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute:$second $period';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _contactSupport(BuildContext context) async {
    final phoneNumber = '2347035743427';
    final message = 'Hello, I need help with transaction ${transaction.reference}';
    final whatsappUrl = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp. Please make sure it is installed.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Get display-friendly details from transaction
  Map<String, String> _getTransactionDetails() {
    Map<String, String> details = {};
    final data = transaction.transactionable ?? {};

    switch (transaction.category) {
      case 'giftcard':
        details['Card Type'] = data['type']?.toString() ?? 'N/A';
        details['Card Name'] = data['card_type']?.toString() ?? 'N/A';
        details['Quantity'] = data['quantity']?.toString() ?? '1';
        details['Card Value'] = '₦${data['amount']?.toString() ?? transaction.amount.toStringAsFixed(0)}';
        break;

      case 'crypto':
        details['Coin'] = data['crypto']?['name']?.toString() ?? 'N/A';
        details['Symbol'] = data['crypto']?['symbol']?.toString() ?? 'N/A';
        details['Wallet Address'] = data['wallet_address']?.toString() ?? 'N/A';
        details['Rate'] = data['crypto']?['usd_rate']?.toString() ?? 'N/A';
        break;

      case 'airtime':
        details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
        details['Phone Number'] = data['phone']?.toString() ?? 'N/A';
        break;

      case 'airtime_swap':
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
        if (data['admin_note'] != null && data['admin_note'].toString().isNotEmpty) {
          details['Admin Note'] = data['admin_note']?.toString() ?? '';
        }
        break;

      case 'bill':
        details['Provider'] = data['bill']?['name']?.toString() ?? 'N/A';
        details['Meter Number'] = data['account_number']?.toString() ?? 'N/A';
        if (data['token'] != null && data['token'].toString().isNotEmpty) {
          details['Token'] = data['token']?.toString() ?? 'N/A';
        }
        break;

      case 'cable':
        details['Provider'] = data['cable']?['name']?.toString() ?? 'N/A';
        details['Plan'] = data['cable_plan']?['name']?.toString() ?? 'N/A';
        details['Smartcard Number'] = data['iuc_number']?.toString() ?? 'N/A';
        break;

      case 'data':
        details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
        details['Phone Number'] = data['phone']?.toString() ?? 'N/A';
        details['Plan'] = data['data_price']?['plan_name']?.toString() ?? 'N/A';
        details['Validity'] = data['data_price']?['validity']?.toString() ?? 'N/A';
        break;

      case 'wallet_funding':
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

      case 'wallet_transfer':
        details['Description'] = data['description']?.toString() ?? 'Gift Transfer';
        details['Channel'] = data['channel']?.toString().toUpperCase() ?? 'WALLET';
        details['Currency'] = data['currency']?.toString() ?? 'NGN';
        break;

      case 'betting':
        details['Category'] = data['category']?.toString() ?? 'N/A';
        details['Event'] = data['event']?.toString() ?? 'N/A';
        if (data['odds'] != null) {
          details['Odds'] = data['odds']?.toString() ?? '';
        }
        break;

      case 'edupin':
        details['Type'] = data['type']?.toString() ?? 'N/A';
        if (data['pin'] != null && data['pin'].toString().isNotEmpty) {
          details['PIN'] = data['pin']?.toString() ?? 'N/A';
        }
        break;
    }

    return details;
  }

  /// Convert UnifiedTransaction to TransactionModel for PDF compatibility
  TransactionModel _toTransactionModel() {
    return TransactionModel(
      id: transaction.id,
      type: transaction.categoryLabel,
      title: transaction.title,
      details: transaction.details,
      date: transaction.createdAt,
      amount: transaction.amount,
      status: transaction.status,
      reference: transaction.reference,
      provider: transaction.provider ?? '',
      rawData: transaction.rawData,
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      // Convert to TransactionModel for PDF service compatibility
      final transactionModel = _toTransactionModel();
      final pdfFile = await PdfService.generateReceipt(transactionModel);

      if (context.mounted) {
        Navigator.pop(context);
      }

      await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf')],
        text: 'Transaction Receipt - ${transaction.reference}',
        subject: 'Receipt for ${transaction.categoryLabel}',
      );
    } catch (e) {
      print('Share error: $e');
      if (context.mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error sharing receipt. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _shareReceipt(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getColorForCategory(transaction.category);
    final isCredit = transaction.type == 'credit';
    final transactionDetails = _getTransactionDetails();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor, typeColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'Transaction Details',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: () => _shareReceipt(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Transaction Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForCategory(transaction.category),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${isCredit ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        transaction.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            Positioned(
              top: 230,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Card
                      _buildInfoCard([
                        _buildInfoRow('Transaction Type', transaction.title),
                        _buildInfoRow('Category', transaction.categoryLabel),
                        _buildInfoRowWithCopy(context, 'Reference', transaction.reference),
                        _buildInfoRow('Date & Time', _formatDateTime(transaction.createdAt)),
                        if (transaction.provider != null && transaction.provider!.isNotEmpty)
                          _buildInfoRow('Provider', transaction.provider!),
                      ]),
                      
                      const SizedBox(height: 16),
                      
                      // Balance Info Card
                      _buildInfoCard([
                        _buildInfoRow('Balance Before', '₦${transaction.balanceBefore.toStringAsFixed(2)}'),
                        _buildInfoRow('Amount', '₦${transaction.amount.toStringAsFixed(2)}'),
                        _buildInfoRow('Balance After', '₦${transaction.balanceAfter.toStringAsFixed(2)}'),
                      ]),
                      
                      // Dynamic Details Card (if any)
                      if (transactionDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          transactionDetails.entries.map((entry) {
                            if (entry.key == 'Token' || entry.key == 'PIN' || entry.key == 'Reference') {
                              return _buildInfoRowWithCopy(context, entry.key, entry.value);
                            }
                            return _buildInfoRow(entry.key, entry.value);
                          }).toList(),
                        ),
                      ],
                      
                      // Description Card
                      if (transaction.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard([
                          _buildInfoRow('Description', transaction.description),
                        ]),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _contactSupport(context),
                              icon: const Icon(Icons.support_agent),
                              label: const Text('Contact Support'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _shareReceipt(context),
                              icon: const Icon(Icons.share),
                              label: const Text('Share Receipt'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textColor.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithCopy(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textColor.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _copyToClipboard(context, value, label),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy,
                    size: 14,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
