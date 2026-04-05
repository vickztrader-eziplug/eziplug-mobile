import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import 'transactions_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel get transaction => widget.transaction;

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
    _showReportForm(context);
  }

  void _showReportForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportFormSheet(
        reference: transaction.reference,
        transactionType: transaction.type,
      ),
    );
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

  // Future<void> _shareReceipt(BuildContext context) async {
  //   try {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (context) => const Center(
  //         child: CircularProgressIndicator(color: AppColors.primary),
  //       ),
  //     );

  //     final pdfFile = await PdfService.generateReceipt(transaction);

  //     if (context.mounted) {
  //       Navigator.pop(context);
  //     }

  //     await FlutterShare.shareFile(
  //       title: 'Transaction Receipt',
  //       text: 'Transaction Receipt - ${transaction.reference}',
  //       filePath: pdfFile.path,
  //       chooserTitle: 'Share Receipt',
  //     );
  //   } catch (e) {
  //     if (context.mounted) {
  //       Navigator.pop(context);

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error generating receipt: $e'),
  //           backgroundColor: Colors.red,
  //           behavior: SnackBarBehavior.floating,
  //         ),
  //       );
  //     }
  //   }
  // }

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


      final result = await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf')],
        text: 'Transaction Receipt - ${transaction.reference}',
        subject: 'Receipt for ${transaction.type}',
      );

  
      if (result.status == ShareResultStatus.success) {
        print('Receipt shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('Share dismissed by user');
      } else if (result.status == ShareResultStatus.unavailable) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sharing is not available on this device'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
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
    final statusColor = _getStatusColor(transaction.status);
    final typeColor = _getColorForType(transaction.type);
    final isPositive = _isPositiveTransaction();
    final transactionDetails = _getTransactionDetails();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? theme.scaffoldBackgroundColor : typeColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SizedBox.expand(
          child: Stack(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor.withOpacity(0.8)]
                      : [typeColor, typeColor.withOpacity(0.8)],
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
                              icon: Icon(
                                Icons.arrow_back,
                                color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Text(
                                'Transaction Details',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                            // Share Button
                            IconButton(
                              icon: Icon(Icons.share, color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white),
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
                          color: isDark ? theme.cardColor : Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                        ),
                        child: Icon(
                          _getIconForType(transaction.type),
                          color: isDark ? typeColor : Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Amount
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '${isPositive ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white,
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
                          color: isDark ? theme.cardColor : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                        ),
                        child: Text(
                          transaction.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? statusColor : Colors.white,
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
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
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
                                    : (isDark ? AppColors.primaryLight : AppColors.primary),
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
                                    'Share',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                    side: BorderSide(
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Report Button (always visible)
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _contactSupport(context),
                                  icon: const Icon(Icons.report_problem, size: 20),
                                  label: const Text(
                                    'Report',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color ?? AppColors.textColor,
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
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
    final theme = Theme.of(context);
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
              color: theme.textTheme.bodySmall?.color ?? AppColors.textColor.withOpacity(0.6),
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
                          color: valueColor ?? theme.textTheme.bodyLarge?.color ?? AppColors.textColor,
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
                      color: theme.textTheme.bodySmall?.color ?? AppColors.textColor.withOpacity(0.5),
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
      child: Divider(height: 1, color: Theme.of(context).dividerColor),
    );
  }
}

/// Report Form Sheet for submitting support tickets
class ReportFormSheet extends StatefulWidget {
  final String reference;
  final String transactionType;

  const ReportFormSheet({
    super.key,
    required this.reference,
    required this.transactionType,
  });

  @override
  State<ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<ReportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ToastHelper.showError('Error selecting image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ToastHelper.showError('Error taking photo: $e');
    }
  }

  void _showImageSourcePicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        ToastHelper.showError('Please login to submit a report');
        setState(() => _isSubmitting = false);
        return;
      }

      final uri = Uri.parse('${Constants.baseUrl}/support/tickets');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      
      request.fields['reference'] = widget.reference;
      request.fields['transaction_type'] = widget.transactionType;
      request.fields['title'] = _titleController.text.trim();
      request.fields['message'] = _messageController.text.trim();

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'attachment',
          bytes,
          filename: _selectedImage!.name,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Support ticket response: ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ToastHelper.showSuccess('Report submitted successfully');
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        ToastHelper.showError(data['message'] ?? 'Failed to submit report');
      }
    } catch (e) {
      print('Error submitting report: $e');
      ToastHelper.showError('Error submitting report. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.report_problem, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Report Issue',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.textTheme.titleLarge?.color),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: theme.dividerColor),
          
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reference (read-only)
                    Text(
                      'Transaction Reference',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                      ),
                      child: Text(
                        widget.reference,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Title
                    Text(
                      'Subject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        hintText: 'Brief description of the issue',
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Message
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe your issue in detail...',
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe your issue';
                        }
                        if (value.trim().length < 10) {
                          return 'Please provide more details (at least 10 characters)';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Attachment
                    Text(
                      'Attachment (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_selectedImage != null && _imageBytes != null) ...[
                      Stack(
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                  _imageBytes = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _showImageSourcePicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: isDark ? Colors.white12 : Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add screenshot or photo',
                                style: TextStyle(
                                  color: isDark ? Colors.white24 : Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 30),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
