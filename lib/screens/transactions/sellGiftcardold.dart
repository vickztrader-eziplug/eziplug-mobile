import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class SellGiftCardScreen extends StatefulWidget {
  const SellGiftCardScreen({super.key});

  @override
  State<SellGiftCardScreen> createState() => _SellGiftCardScreenState();
}

class _SellGiftCardScreenState extends State<SellGiftCardScreen> {
  String? _selectedCountry;
  String? _selectedGiftCard;
  String? _selectedCategory;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _youreGettingController = TextEditingController();
  List<File> _uploadedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  final List<String> _countries = [
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Nigeria',
    'Ghana',
    'South Africa',
    'Kenya',
  ];

  final List<String> _giftCards = [
    'iTunes',
    'Amazon',
    'Google Play',
    'Steam',
    'Razer Gold',
    'Roblox',
    'Vanilla',
    'Visa',
    'Walmart',
  ];

  final List<String> _categories = ['Physical', 'E-code', 'Receipt'];

  @override
  void dispose() {
    _amountController.dispose();
    _youreGettingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Improved authentication check that doesn't force logout
  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    // Only redirect if definitely not authenticated and the widget is still mounted
    if ((token == null || token.isEmpty) && mounted) {
      // Use push instead of pushReplacement to allow going back
      // Navigator.pushNamed(context, '/login');
      print('not authenticated$token');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);

      if (images.isNotEmpty) {
        setState(() {
          _uploadedImages = images.map((image) => File(image.path)).toList();
        });
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_selectedCountry == null) {
      _showSnackBar('Please select a country', Colors.red);
      return;
    }
    if (_selectedGiftCard == null) {
      _showSnackBar('Please select a gift card', Colors.red);
      return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category', Colors.red);
      return;
    }
    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter amount', Colors.red);
      return;
    }
    if (_uploadedImages.isEmpty) {
      _showSnackBar('Please upload at least one image', Colors.red);
      return;
    }

    // Check auth right before proceeding to PIN
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    print('token: $token');

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Transaction',
          subtitle: 'Enter your 4 digit PIN to sell gift card',
          onPinComplete: (pin) => _sellGiftCard(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _sellGiftCard(String pin) async {
    setState(() => _isLoading = true); // Show loader

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(Constants.sellGiftCardUrl),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['country'] = _selectedCountry!;
      request.fields['card_type'] = _selectedGiftCard!;
      request.fields['category'] = _selectedCategory!;
      request.fields['amount'] = _amountController.text;
      request.fields['pin'] = pin;

      for (var i = 0; i < _uploadedImages.length; i++) {
        var image = _uploadedImages[i];
        var stream = http.ByteStream(image.openRead());
        var length = await image.length();

        var multipartFile = http.MultipartFile(
          'images[]',
          stream,
          length,
          filename: 'giftcard_$i.jpg',
        );
        request.files.add(multipartFile);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (!mounted) return;
      print('responseData: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Transaction Successful',
              subtitle: 'Your gift card has been sold successfully',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['transaction_id'] ?? 'N/A',
                ),
                ReceiptDetail(label: 'Gift Card', value: _selectedGiftCard!),
                ReceiptDetail(label: 'Category', value: _selectedCategory!),
                ReceiptDetail(
                  label: 'Amount',
                  value: '\$${_amountController.text}',
                ),
                ReceiptDetail(
                  label: 'You Received',
                  value: '₦${_youreGettingController.text}',
                ),
                ReceiptDetail(
                  label: 'Date',
                  value: DateTime.now().toString().split('.')[0],
                ),
              ],
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        Navigator.pop(context); // Close PIN screen
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to sell gift card',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false); // Hide loader
    }
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
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),
            // Header Section
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
                    const SizedBox(height: 30),
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
                              'Sell Gift Card',
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
                  ],
                ),
              ),
            ),

            // Content Section with curved top
            Positioned(
              top: 130,
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
                      // Country Dropdown
                      _buildLabel('Country'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        hint: 'Select country',
                        value: _selectedCountry,
                        items: _countries,
                        onChanged: (value) {
                          setState(() => _selectedCountry = value);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Gift Card Dropdown
                      _buildLabel('Gift Card'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        hint: 'Select gift card',
                        value: _selectedGiftCard,
                        items: _giftCards,
                        onChanged: (value) {
                          setState(() => _selectedGiftCard = value);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Category Dropdown
                      _buildLabel('Category'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        hint: 'Select a category',
                        value: _selectedCategory,
                        items: _categories,
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Amount TextField
                      _buildLabel('Amount'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _amountController,
                        hintText: 'Enter gift card amount',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      // You're Getting Box
                      _buildLabel('You\'re Getting'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _youreGettingController.text.isEmpty
                              ? '₦ 0.00'
                              : '₦ ${_youreGettingController.text}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Upload Gift Card Image(s)
                      _buildLabel('Upload Gift Card Image(s)'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _isLoading ? null : _pickImages,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppColors.lightGrey,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 40,
                                color: AppColors.textColor.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _uploadedImages.isEmpty
                                    ? 'Click here to upload image(s)'
                                    : '${_uploadedImages.length} image(s) selected',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textColor.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Proceed Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.lightGrey,
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 2),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
        ),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
