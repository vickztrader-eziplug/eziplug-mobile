import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pdf_service.dart';
import 'transactions_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'completed' ||
        statusLower == 'success' ||
        statusLower == 'successful') {
      return Colors.green;
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      return Colors.orange;
    } else if (statusLower == 'failed' ||
        statusLower == 'cancelled' ||
        statusLower == 'rejected') {
      return Colors.red;
    }
    return Colors.grey;
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Giftcard':
        return AppColors.primary;
      case 'Crypto':
        return AppColors.primary;
      case 'Airtime':
        return AppColors.primary;
      case 'Airtime Swap':
        return AppColors.primary;
      case 'Bill':
        return AppColors.primary;
      case 'Cable':
        return AppColors.primary;
      case 'Data':
        return AppColors.primary;
      case 'Payment':
        return AppColors.primary;
      case 'User Gift':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Giftcard':
        return Icons.card_giftcard;
      case 'Crypto':
        return Icons.currency_bitcoin;
      case 'Airtime':
        return Icons.phone_android;
      case 'Airtime Swap':
        return Icons.swap_horiz;
      case 'Bill':
        return Icons.lightbulb_outline;
      case 'Cable':
        return Icons.tv;
      case 'Data':
        return Icons.wifi;
      case 'Payment':
        return Icons.payment;
      case 'User Gift':
        return Icons.card_giftcard;
      default:
        return Icons.receipt;
    }
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    String hour = date.hour.toString().padLeft(2, '0');
    String minute = date.minute.toString().padLeft(2, '0');
    String second = date.second.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute:$second';
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
    final message =
        'Hello, I need help with transaction ${transaction.reference}';
    final whatsappUrl =
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open WhatsApp. Please make sure it is installed.',
              ),
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

  Map<String, String> _getTransactionDetails() {
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
        details['Crypto Amount'] =
            data['naira_equivalent']?.toString() ?? 'N/A';
        details['Rate'] = data['crypto']?['usd_rate']?.toString() ?? 'N/A';
        break;

      case 'Airtime':
        details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
        details['Phone Number'] = data['phone']?.toString() ?? 'N/A';
        break;

      case 'Airtime Swap':
        details['Network'] = data['network']?['name']?.toString() ?? 'N/A';
        details['Phone Number'] = data['phone_number']?.toString() ?? 'N/A';
        details['Airtime Amount'] =
            '₦${data['airtime_amount']?.toString() ?? '0'}';
        details['Cash Amount'] = '₦${data['cash_amount']?.toString() ?? '0'}';
        details['Conversion Rate'] =
            '${data['conversion_rate']?.toString() ?? '0'}%';
        if (data['account_number'] != null &&
            data['account_number'].toString().isNotEmpty) {
          details['Account Number'] = data['account_number']?.toString() ?? '';
          details['Account Name'] = data['account_name']?.toString() ?? 'N/A';
          details['Bank Name'] = data['bank_name']?.toString() ?? 'N/A';
        }
        if (data['admin_note'] != null &&
            data['admin_note'].toString().isNotEmpty) {
          details['Admin Note'] = data['admin_note']?.toString() ?? '';
        }
        break;

      case 'Bill':
        details['Provider'] = data['bill']?['name']?.toString() ?? 'N/A';
        details['Meter Number'] = data['account_number']?.toString() ?? 'N/A';
        if (data['token'] != null && data['token'].toString().isNotEmpty) {
          details['Token'] = data['token']?.toString() ?? 'N/A';
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
        details['Validity'] =
            data['data_price']?['validity']?.toString() ?? 'N/A';
        break;

      case 'Payment':
        details['Payment Method'] =
            data['type']?.toString().toUpperCase() ?? 'N/A';
        details['Gateway'] = data['gateway']?.toString().toUpperCase() ?? 'N/A';
        details['Currency'] = data['currency']?.toString() ?? 'NGN';

        if (data['gateway_reference'] != null) {
          details['Gateway Reference'] =
              data['gateway_reference']?.toString() ?? '';
        }

        if (data['card_type'] != null &&
            data['card_type'].toString().isNotEmpty) {
          details['Card Type'] = data['card_type']?.toString() ?? '';
          details['Last 4 Digits'] = data['last4']?.toString() ?? 'N/A';
        }

        if (data['account_number'] != null &&
            data['account_number'].toString().isNotEmpty) {
          details['Account Number'] = data['account_number']?.toString() ?? '';
          details['Bank Name'] = data['bank_name']?.toString() ?? 'N/A';
        }

        details['Description'] =
            data['description']?.toString() ?? 'Wallet Funding';

        if (data['paid_at'] != null) {
          details['Paid At'] = data['paid_at']?.toString() ?? '';
        }
        break;

      case 'User Gift':
        details['Description'] =
            data['description']?.toString() ?? 'Gift Transfer';
        details['Channel'] =
            data['channel']?.toString().toUpperCase() ?? 'WALLET';
        details['Currency'] = data['currency']?.toString() ?? 'NGN';
        details['Bank'] = data['bank']?.toString() ?? 'Wallet';
        break;
    }

    return details;
  }

  bool _isPositiveTransaction() {
    if (transaction.type == 'Payment') return true;

    if (transaction.type == 'User Gift') return false;

    return false;
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

      final pdfFile = await PdfService.generateReceipt(transaction);

      if (context.mounted) {
        Navigator.pop(context);
      }

      await FlutterShare.shareFile(
        title: 'Transaction Receipt',
        text: 'Transaction Receipt - ${transaction.reference}',
        filePath: pdfFile.path,
        chooserTitle: 'Share Receipt',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating receipt: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(transaction.status);
    final typeColor = _getColorForType(transaction.type);
    final isPositive = _isPositiveTransaction();
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
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
                          const SizedBox(width: 48),
                          // Share Button
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
                        _getIconForType(transaction.type),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${isPositive ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
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
                      // Basic Information Card
                      _buildSectionCard(
                        title: 'Basic Information',
                        children: [
                          _buildDetailRow(
                            'Transaction Type',
                            transaction.type,
                            canCopy: false,
                            context: context,
                          ),
                          _buildDivider(),
                          _buildDetailRow(
                            'Reference',
                            transaction.reference,
                            canCopy: true,
                            context: context,
                          ),
                          _buildDivider(),
                          _buildDetailRow(
                            'Transaction ID',
                            transaction.id,
                            canCopy: true,
                            context: context,
                          ),
                          _buildDivider(),
                          _buildDetailRow(
                            'Date & Time',
                            _formatDateTime(transaction.date),
                            canCopy: false,
                            context: context,
                          ),
                          _buildDivider(),
                          _buildDetailRow(
                            'Status',
                            transaction.status,
                            canCopy: false,
                            context: context,
                            valueColor: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Transaction Specific Details
                      if (transactionDetails.isNotEmpty)
                        _buildSectionCard(
                          title: 'Transaction Details',
                          children: transactionDetails.entries.map((entry) {
                            bool isLast =
                                entry.key ==
                                transactionDetails.entries.last.key;
                            return Column(
                              children: [
                                _buildDetailRow(
                                  entry.key,
                                  entry.value,
                                  canCopy:
                                      entry.key.contains('Number') ||
                                      entry.key.contains('Address') ||
                                      entry.key.contains('Pin') ||
                                      entry.key.contains('Token') ||
                                      entry.key.contains('Reference'),
                                  context: context,
                                ),
                                if (!isLast) _buildDivider(),
                              ],
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),

                      // Amount Breakdown Card
                      _buildSectionCard(
                        title: 'Amount Details',
                        children: [
                          _buildDetailRow(
                            'Amount',
                            '₦${transaction.amount.toStringAsFixed(2)}',
                            canCopy: false,
                            context: context,
                            valueStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? Colors.green
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Action Buttons
                      Row(
                        children: [
                          // Share Button
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () => _shareReceipt(context),
                                icon: const Icon(Icons.share, size: 20),
                                label: const Text(
                                  'Share Receipt',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Support Button (if needed)
                          if (transaction.status.toLowerCase() == 'pending' ||
                              transaction.status.toLowerCase() == 'failed') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _contactSupport(context),
                                  icon: const Icon(Icons.headset_mic, size: 20),
                                  label: const Text(
                                    'Support',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    required bool canCopy,
    required BuildContext context,
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style:
                        valueStyle ??
                        TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? AppColors.textColor,
                        ),
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _copyToClipboard(context, value, label),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: AppColors.textColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, color: AppColors.lightGrey.withOpacity(0.3)),
    );
  }
}
