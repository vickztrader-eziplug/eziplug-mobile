import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import 'GiftCardConfirmationScreen.dart';

class SellGiftCardScreen extends StatefulWidget {
  const SellGiftCardScreen({super.key});

  @override
  State<SellGiftCardScreen> createState() => _SellGiftCardScreenState();
}

class _SellGiftCardScreenState extends State<SellGiftCardScreen> {
  List<dynamic> _giftCards = [];
  List<dynamic> _countries = [];
  List<dynamic> _priceRanges = [];

  dynamic _selectedGiftCard;
  dynamic _selectedCountry;
  dynamic _selectedPriceRange;
  String _selectedCategory = 'E-code';

  final TextEditingController _amountUsdController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  bool _isLoading = true;
  bool _isCalculating = false;
  double _amountNgn = 0.0;
  double _rate = 0.0;

  List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchGiftCards();
  }

  @override
  void dispose() {
    _amountUsdController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchGiftCards() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      print('Fetching gift cards from: ${Constants.giftCards}');

      final response = await http.get(
        Uri.parse(Constants.giftCards),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response structures
        List<dynamic> giftCardsData = [];

        if (data['data'] != null) {
          giftCardsData = data['data'];
        } else if (data['results'] != null && data['results']['data'] != null) {
          giftCardsData = data['results']['data'];
        } else if (data is List) {
          giftCardsData = data;
        }

        print('Parsed gift cards: ${giftCardsData.length}');

        if (mounted) {
          setState(() {
            _giftCards = giftCardsData;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load gift cards: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching gift cards: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load gift cards: ${e.toString()}', Colors.red);
      }
    }
  }

  void _onGiftCardSelected(dynamic giftCard) {
    setState(() {
      _selectedGiftCard = giftCard;
      _countries = giftCard['countries'] ?? [];
      _selectedCountry = null;
      _selectedPriceRange = null;
      _priceRanges = [];
      _amountUsdController.clear();
      _amountNgn = 0.0;
      _selectedImages.clear();
    });
  }

  void _onCountrySelected(dynamic country) {
    setState(() {
      _selectedCountry = country;
      _priceRanges = country['price_ranges'] ?? [];
      _selectedPriceRange = null;
      _rate = double.parse(country['sell_rate'].toString());
      _amountUsdController.clear();
      _amountNgn = 0.0;
    });
  }

  void _onPriceRangeSelected(dynamic priceRange) {
    setState(() {
      _selectedPriceRange = priceRange;
      _amountUsdController.text = priceRange['min_amount'].toString();
      _calculateNairaAmount();
    });
  }

  Future<void> _calculateNairaAmount() async {
    if (_amountUsdController.text.isEmpty || _rate == 0) return;

    setState(() => _isCalculating = true);

    try {
      final amountUsd = double.parse(_amountUsdController.text);
      final quantity = int.parse(_quantityController.text);

      setState(() {
        _amountNgn = amountUsd * _rate * quantity;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages = pickedFiles
              .take(5) // Maximum 5 images
              .map((xFile) => File(xFile.path))
              .toList();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick images', Colors.red);
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null && _selectedImages.length < 5) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      _showSnackBar('Failed to take picture', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _proceedToConfirmation() {
    // Validation
    if (_selectedGiftCard == null) {
      _showSnackBar('Please select a gift card', Colors.red);
      return;
    }
    if (_selectedCountry == null) {
      _showSnackBar('Please select a country', Colors.red);
      return;
    }
    if (_selectedPriceRange == null) {
      _showSnackBar('Please select a price range', Colors.red);
      return;
    }
    if (_amountUsdController.text.isEmpty) {
      _showSnackBar('Please enter amount in USD', Colors.red);
      return;
    }
    if (_selectedImages.isEmpty) {
      _showSnackBar('Please upload at least one card image', Colors.red);
      return;
    }

    final amountUsd = double.parse(_amountUsdController.text);
    final minAmount = double.parse(
      _selectedPriceRange['min_amount'].toString(),
    );
    final maxAmount = double.parse(
      _selectedPriceRange['max_amount'].toString(),
    );

    if (amountUsd < minAmount || amountUsd > maxAmount) {
      _showSnackBar(
        'Amount must be between \$$minAmount and \$$maxAmount',
        Colors.red,
      );
      return;
    }

    // Navigate to confirmation screen - Pass File objects, not paths
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GiftCardConfirmationScreen(
          type: 'sell',
          giftCard: _selectedGiftCard,
          country: _selectedCountry,
          priceRange: _selectedPriceRange,
          category: _selectedCategory,
          amountUsd: double.parse(_amountUsdController.text),
          amountNgn: _amountNgn,
          rate: _rate,
          quantity: int.parse(_quantityController.text),
          imageFiles: _selectedImages, // Pass actual File objects
        ),
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

            // Content Section with Curved Top
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _giftCards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.card_giftcard,
                              size: 64,
                              color: AppColors.lightGrey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No gift cards available',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _fetchGiftCards,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gift Card Selection
                            _buildLabel('Select Gift Card'),
                            const SizedBox(height: 12),
                            _buildGiftCardGrid(),
                            const SizedBox(height: 24),

                            if (_selectedGiftCard != null) ...[
                              // Country Selection
                              _buildLabel('Select Country'),
                              const SizedBox(height: 12),
                              _buildCountryGrid(),
                              const SizedBox(height: 24),
                            ],

                            if (_selectedCountry != null) ...[
                              // Category Selection
                              _buildLabel('Category'),
                              const SizedBox(height: 12),
                              _buildCategorySelector(),
                              const SizedBox(height: 24),

                              // Price Range Selection
                              _buildLabel('Select Price Range'),
                              const SizedBox(height: 12),
                              _buildPriceRangeList(),
                              const SizedBox(height: 24),

                              // Amount in USD
                              _buildLabel('Amount (USD)'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _amountUsdController,
                                hintText: 'Enter amount in USD',
                                keyboardType: TextInputType.number,
                                prefix: '\$',
                                onChanged: (value) => _calculateNairaAmount(),
                              ),
                              const SizedBox(height: 16),

                              // Quantity
                              _buildLabel('Quantity'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _quantityController,
                                hintText: 'Enter quantity',
                                keyboardType: TextInputType.number,
                                onChanged: (value) => _calculateNairaAmount(),
                              ),
                              const SizedBox(height: 24),

                              // Upload Card Images
                              _buildLabel('Upload Card Images (Max 5)'),
                              const SizedBox(height: 12),
                              _buildImageUploadSection(),
                              const SizedBox(height: 24),

                              // Amount Preview
                              if (_amountNgn > 0) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Rate:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '₦${_rate.toStringAsFixed(2)}/\$1',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'You will receive:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '₦${_amountNgn.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),
                              ],

                              // Proceed Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      _amountNgn > 0 &&
                                          _selectedImages.isNotEmpty
                                      ? _proceedToConfirmation
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor:
                                        AppColors.lightGrey,
                                  ),
                                  child: const Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildGiftCardGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _giftCards.length,
      itemBuilder: (context, index) {
        final giftCard = _giftCards[index];
        final isSelected = _selectedGiftCard?['id'] == giftCard['id'];

        return GestureDetector(
          onTap: () => _onGiftCardSelected(giftCard),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.lightGrey,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                giftCard['logo_url'] != null
                    ? Image.network(
                        giftCard['logo_url'],
                        height: 50,
                        width: 50,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.card_giftcard,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.card_giftcard,
                        size: 50,
                        color: AppColors.primary,
                      ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    giftCard['name'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _countries.length,
      itemBuilder: (context, index) {
        final country = _countries[index];
        final countryData = country['country'];
        final isSelected = _selectedCountry?['id'] == country['id'];

        return GestureDetector(
          onTap: () => _onCountrySelected(country),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.lightGrey,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                countryData['flag_url'] != null
                    ? Image.network(
                        countryData['flag_url'],
                        height: 32,
                        width: 32,
                        errorBuilder: (_, __, ___) => Text(
                          countryData['code'] ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                      )
                    : Text(
                        countryData['code'] ?? '',
                        style: const TextStyle(fontSize: 24),
                      ),
                const SizedBox(height: 6),
                Text(
                  countryData['code'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return Row(
      children: [
        Expanded(child: _buildCategoryOption('E-code')),
        const SizedBox(width: 12),
        Expanded(child: _buildCategoryOption('Physical')),
      ],
    );
  }

  Widget _buildCategoryOption(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _priceRanges = _selectedCountry['price_ranges']
              .where((r) => r['category'] == category)
              .toList();
          _selectedPriceRange = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightGrey,
          ),
        ),
        child: Text(
          category,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRangeList() {
    final filteredRanges = _priceRanges
        .where((r) => r['category'] == _selectedCategory)
        .toList();

    if (filteredRanges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No price ranges available for this category',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.darkGrey),
        ),
      );
    }

    return Column(
      children: filteredRanges.map<Widget>((range) {
        final isSelected = _selectedPriceRange?['id'] == range['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _onPriceRangeSelected(range),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.lightGrey,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.primary : AppColors.lightGrey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    range['display_text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        // Upload buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedImages.length < 5 ? _pickImages : null,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedImages.length < 5 ? _takePicture : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Display selected images
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        // Image count indicator
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${_selectedImages.length} of 5 images selected',
              style: TextStyle(fontSize: 12, color: AppColors.darkGrey),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          prefixText: prefix,
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
