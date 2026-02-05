import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/pin_verification_modal.dart';

class GiftCardConfirmationScreen extends StatefulWidget {
  final String type; // 'buy' or 'sell'
  final dynamic giftCard;
  final dynamic country;
  final dynamic priceRange;
  final String category;
  final double amountUsd;
  final double amountNgn;
  final double rate;
  final int quantity;
  final List<String>? images; // For sell only - paths (deprecated)
  final List<XFile>? imageFiles; // For sell only - XFile for cross-platform support

  const GiftCardConfirmationScreen({
    super.key,
    required this.type,
    required this.giftCard,
    required this.country,
    required this.priceRange,
    required this.category,
    required this.amountUsd,
    required this.amountNgn,
    required this.rate,
    required this.quantity,
    this.images,
    this.imageFiles,
  });

  @override
  State<GiftCardConfirmationScreen> createState() =>
      _GiftCardConfirmationScreenState();
}

class _GiftCardConfirmationScreenState
    extends State<GiftCardConfirmationScreen> {
  String _transactionRef = '';

  @override
  void initState() {
    super.initState();
    _transactionRef = _generateTransactionRef();
  }

  String _generateTransactionRef() {
    return 'GC${DateTime.now().millisecondsSinceEpoch}';
  }

  void _proceedToTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GiftCardTermsScreen(
          type: widget.type,
          transactionData: {
            'gift_card_country_id': widget.country['id'],
            'price_range_id': widget.priceRange['id'],
            'category': widget.category,
            'amount_usd': widget.amountUsd,
            'quantity': widget.quantity,
          },
          imageFiles: widget.imageFiles, // Pass File objects for sell
          transactionRef: _transactionRef,
          amountUsd: widget.amountUsd,
          amountNgn: widget.amountNgn,
          rate: widget.rate,
          giftCardName: widget.giftCard['name'],
          countryName: widget.country['country']['name'],
          // type: widget.type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.amountNgn * widget.quantity;
    final isBuy = widget.type == 'buy';

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section with Curved Design
            Container(
              width: double.infinity,
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Back Button and Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Confirm Transaction',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Icon and Type
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isBuy ? Icons.shopping_bag : Icons.sell,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isBuy ? 'Buying' : 'Selling'} Gift Card',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section with Curved Top
            Positioned(
              top: 190,
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
                      // Transaction Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transaction Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor,
                              ),
                            ),
                            const Divider(height: 24),
                            _buildDetailRow('Transaction Ref', _transactionRef),
                            _buildDetailRow(
                              'Date',
                              DateTime.now().toString().split('.')[0],
                            ),
                            _buildDetailRow(
                              'Gift Card',
                              widget.giftCard['name'],
                            ),
                            _buildDetailRow(
                              'Country',
                              widget.country['country']['name'],
                            ),
                            _buildDetailRow('Category', widget.category),
                            _buildDetailRow(
                              'Quantity',
                              widget.quantity.toString(),
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Amount (USD)',
                              '\$${widget.amountUsd.toStringAsFixed(2)}',
                            ),
                            _buildDetailRow(
                              'Rate',
                              '₦${widget.rate.toStringAsFixed(2)}/\$1',
                            ),
                            _buildDetailRow(
                              'Amount (NGN)',
                              '₦${widget.amountNgn.toStringAsFixed(2)}',
                            ),
                            if (widget.quantity > 1)
                              _buildDetailRow(
                                'Total Amount',
                                '₦${totalAmount.toStringAsFixed(2)}',
                                isBold: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Amount Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isBuy
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isBuy ? AppColors.primary : Colors.green,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isBuy ? 'You will pay:' : 'You will receive:',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₦${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isBuy ? AppColors.primary : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Proceed Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _proceedToTerms,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Proceed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textColor.withOpacity(0.7),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Terms and Conditions Screen
// ============================================

class GiftCardTermsScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic> transactionData;
  final List<XFile>? imageFiles; // XFile objects for sell (cross-platform)
  final String transactionRef;
  final double amountUsd;
  final double amountNgn;
  final double rate;
  final String giftCardName;
  final String countryName;

  const GiftCardTermsScreen({
    super.key,
    required this.type,
    required this.transactionData,
    this.imageFiles,
    required this.transactionRef,
    required this.amountUsd,
    required this.amountNgn,
    required this.rate,
    required this.giftCardName,
    required this.countryName,
  });

  @override
  State<GiftCardTermsScreen> createState() => _GiftCardTermsScreenState();
}

class _GiftCardTermsScreenState extends State<GiftCardTermsScreen> {
  bool _isAgreed = false;
  bool _isProcessing = false;

  Future<void> _proceedToPin() async {
    if (!_isAgreed) {
      _showSnackBar('Please agree to the terms and conditions', Colors.red);
      return;
    }

    final isBuy = widget.type == 'buy';
    final totalAmount = widget.amountNgn * (widget.transactionData['quantity'] as int? ?? 1);

    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Transaction',
      subtitle: 'Enter your 4-digit PIN to confirm this transaction',
      transactionType: isBuy ? 'Gift Card Purchase' : 'Gift Card Sale',
      recipient: '${widget.giftCardName} (${widget.countryName})',
      amount: '₦${totalAmount.toStringAsFixed(2)}',
      onForgotPin: () {
        _showSnackBar('Go to Profile > PIN Management to reset your PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _processTransaction(pin);
    }
  }

  Future<void> _processTransaction(String pin) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final endpoint = widget.type == 'buy'
          ? Constants.buyGiftCard
          : Constants.sellGiftCard;

      print('Sending ${widget.type} transaction to: $endpoint');

      http.Response response;

      if (widget.type == 'sell' &&
          widget.imageFiles != null &&
          widget.imageFiles!.isNotEmpty) {
        // Use MultipartRequest for sell with images
        var request = http.MultipartRequest('POST', Uri.parse(endpoint));

        // Add headers
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        // Add form fields
        request.fields['gift_card_country_id'] = widget
            .transactionData['gift_card_country_id']
            .toString();
        request.fields['price_range_id'] = widget
            .transactionData['price_range_id']
            .toString();
        request.fields['category'] = widget.transactionData['category'];
        request.fields['amount_usd'] = widget.transactionData['amount_usd']
            .toString();
        request.fields['quantity'] = widget.transactionData['quantity']
            .toString();
        request.fields['pin'] = pin;

        // Add images - use readAsBytes for cross-platform support (web + mobile)
        for (int i = 0; i < widget.imageFiles!.length; i++) {
          var xFile = widget.imageFiles![i];
          var bytes = await xFile.readAsBytes();
          var multipartFile = http.MultipartFile.fromBytes(
            'images[$i]', // Laravel expects images[0], images[1], etc.
            bytes,
            filename: xFile.name,
          );
          request.files.add(multipartFile);
        }

        print('Sending multipart request with ${request.files.length} images');

        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // Use regular JSON POST for buy
        final body = {...widget.transactionData, 'pin': pin};

        print('Body: $body');

        response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      }

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Show success dialog
        _showSuccessDialog(
          responseData['message'] ??
              'Transaction is being processed, await approval',
        );
      } else if (response.statusCode == 400) {
        // Wrong PIN or validation error
        _showSnackBar(
          responseData['message'] ?? 'Invalid PIN or transaction data',
          Colors.red,
        );
      } else {
        throw Exception(responseData['message'] ?? 'Transaction failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Success!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your email for transaction details',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.darkGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Close dialog and all previous screens
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.type == 'buy';

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section with Curved Design
            Container(
              width: double.infinity,
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Terms & Conditions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.article, size: 48, color: Colors.white),
                    const SizedBox(height: 3),
                    const Text(
                      'Please read carefully',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section with Curved Top
            Positioned(
              top: 190,
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
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gift Card ${isBuy ? 'Purchase' : 'Sale'} Terms',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTermItem(
                                '1. All gift card transactions are final and cannot be reversed.',
                              ),
                              _buildTermItem(
                                '2. Please ensure all card details are correct before proceeding.',
                              ),
                              _buildTermItem(
                                '3. Processing time may take 5-30 minutes depending on verification.',
                              ),
                              if (!isBuy)
                                _buildTermItem(
                                  '4. Invalid or used cards will be rejected and no refund will be issued.',
                                ),
                              _buildTermItem(
                                '${!isBuy ? '5' : '4'}. You will receive an email notification once your transaction is processed.',
                              ),
                              _buildTermItem(
                                '${!isBuy ? '6' : '5'}. Eziplug reserves the right to reject any transaction that violates our terms.',
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _isAgreed,
                                      onChanged: (value) {
                                        setState(
                                          () => _isAgreed = value ?? false,
                                        );
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'I have read and agree to the terms and conditions',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isAgreed && !_isProcessing
                              ? _proceedToPin
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: AppColors.lightGrey,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Confirm and Trade',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
