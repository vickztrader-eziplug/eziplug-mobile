import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';

class PaystackWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackWebView({
    super.key,
    required this.authorizationUrl,
    required this.reference,
  });

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isPolling = false;
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPolls = 60; // 5 minutes max (60 * 5 seconds)

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _launchPaymentAndStartPolling();
    } else {
      _initializeMobileWebView();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ===== WEB PLATFORM =====
  Future<void> _launchPaymentAndStartPolling() async {
    final uri = Uri.parse(widget.authorizationUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() {
        _isLoading = false;
        _isPolling = true;
      });
      _startPollingForPayment();
    } catch (e) {
      print('❌ Could not launch payment URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPollingForPayment() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollCount++;
      if (_pollCount >= _maxPolls) {
        timer.cancel();
        setState(() => _isPolling = false);
        return;
      }

      // Check payment status
      final result = await _checkPaymentStatus();
      if (result != null) {
        timer.cancel();
        // Return the full result map so caller has all the data
        Navigator.pop(context, result);
      }
    });
  }

  /// Returns null if still pending, or a Map with result data
  Future<Map<String, dynamic>?> _checkPaymentStatus() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payment/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reference': widget.reference}),
      );

      print('🔍 Polling payment status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == true || result['success'] == true) {
          // Return the full result with success flag
          return {'success': true, 'data': result};
        }
      } else if (response.statusCode == 400) {
        // Payment failed or cancelled
        final result = jsonDecode(response.body);
        final message = result['message']?.toString().toLowerCase() ?? '';
        if (message.contains('failed') || message.contains('cancelled')) {
          return {'success': false, 'message': result['message']};
        }
      }
      return null; // Still pending
    } catch (e) {
      print('❌ Polling error: $e');
      return null;
    }
  }

  // ===== MOBILE PLATFORM =====
  void _initializeMobileWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📍 Page started: $url');
            _checkForCallback(url);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            print('✅ Page finished: $url');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔄 Navigation request: ${request.url}');
            _checkForCallback(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _checkForCallback(String url) {
    // Check if payment was successful or cancelled
    if (url.contains('callback') || url.contains('success') || url.contains('trxref=')) {
      Navigator.pop(context, true); // Payment completed, verify on backend
    } else if (url.contains('cancel') || url.contains('close')) {
      Navigator.pop(context, false); // Payment cancelled
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showCancelDialog,
        ),
      ),
      body: kIsWeb ? _buildWebPlatformUI() : _buildMobileUI(),
    );
  }

  Widget _buildMobileUI() {
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildWebPlatformUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Animated loading indicator
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isPolling)
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                    Icon(
                      Icons.payment,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Complete Your Payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A new tab has opened for you to complete payment.\nThis page will update automatically when done.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Single column of buttons to avoid overflow
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchPaymentAndStartPolling,
                  icon: const Icon(Icons.open_in_new, size: 20),
                  label: const Text('Reopen Payment Page'),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    final result = await _checkPaymentStatus();
                    setState(() => _isLoading = false);
                    if (result != null && result['success'] == true) {
                      Navigator.pop(context, result);
                    } else if (result != null && result['success'] == false) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Payment was not successful'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment still processing...'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  label: const Text('Check Payment Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to cancel this payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Close webview
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
