import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
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

  List<XFile> _selectedImages = [];
  Map<String, Uint8List> _imageBytes = {}; // Cache for web image display
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
        final newImages = pickedFiles.take(5 - _selectedImages.length).toList();
        
        // Cache bytes for web display
        if (kIsWeb) {
          for (final xFile in newImages) {
            _imageBytes[xFile.path] = await xFile.readAsBytes();
          }
        }
        
        setState(() {
          _selectedImages.addAll(newImages);
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
        // Cache bytes for web display
        if (kIsWeb) {
          _imageBytes[photo.path] = await photo.readAsBytes();
        }
        
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to take picture', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removed = _selectedImages.removeAt(index);
      _imageBytes.remove(removed.path); // Clean up cached bytes
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
          imageFiles: _selectedImages, // Pass XFile objects for cross-platform support
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  // Theme color for Sell Giftcard
  static const Color _themeColor = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: _themeColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
        children: [
          // Modern Gradient Header
          ModernFormWidgets.buildGradientHeader(
            context: context,
            title: 'Sell Giftcard',
            subtitle: 'Convert your gift cards to cash',
            primaryColor: _themeColor,
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: _themeColor),
                  )
                : _giftCards.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gift Card Selection Section
                            ModernFormWidgets.buildFormCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ModernFormWidgets.buildSectionLabel(
                                    'Select Gift Card',
                                    icon: Icons.card_giftcard,
                                    iconColor: _themeColor,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGiftCardGrid(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_selectedGiftCard != null) ...[
                              // Country Selection
                              ModernFormWidgets.buildFormCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ModernFormWidgets.buildSectionLabel(
                                      'Select Country',
                                      icon: Icons.public,
                                      iconColor: _themeColor,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildCountryGrid(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            if (_selectedCountry != null) ...[
                              // Category & Price Range
                              ModernFormWidgets.buildFormCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ModernFormWidgets.buildSectionLabel(
                                      'Category',
                                      icon: Icons.category,
                                      iconColor: _themeColor,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCategorySelector(),
                                    const SizedBox(height: 20),
                                    ModernFormWidgets.buildSectionLabel(
                                      'Select Price Range',
                                      icon: Icons.attach_money,
                                      iconColor: _themeColor,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildPriceRangeList(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Amount & Quantity Section
                              ModernFormWidgets.buildFormCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ModernFormWidgets.buildSectionLabel(
                                      'Card Details',
                                      icon: Icons.info_outline,
                                      iconColor: _themeColor,
                                    ),
                                    const SizedBox(height: 16),
                                    ModernFormWidgets.buildTextField(
                                      controller: _amountUsdController,
                                      hintText: 'Enter amount in USD',
                                      label: 'Amount (USD)',
                                      prefixIcon: Icons.attach_money,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                      ],
                                      onChanged: (value) => _calculateNairaAmount(),
                                    ),
                                    const SizedBox(height: 16),
                                    ModernFormWidgets.buildTextField(
                                      controller: _quantityController,
                                      hintText: 'Enter quantity',
                                      label: 'Quantity',
                                      prefixIcon: Icons.numbers,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (value) => _calculateNairaAmount(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Image Upload Section
                              ModernFormWidgets.buildFormCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ModernFormWidgets.buildSectionLabel(
                                      'Upload Card Images (Max 5)',
                                      icon: Icons.photo_library,
                                      iconColor: _themeColor,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildImageUploadSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Amount Preview
                              if (_amountNgn > 0) ...[
                                _buildAmountPreview(),
                                const SizedBox(height: 16),
                              ],

                              // Tips Card
                              ModernFormWidgets.buildInfoCard(
                                message: 'Upload clear images of your gift card (front and back). Ensure card details are visible for faster processing.',
                                icon: Icons.lightbulb_outline,
                                color: _themeColor,
                              ),
                              const SizedBox(height: 24),

                              // Submit Button
                              ModernFormWidgets.buildPrimaryButton(
                                label: 'Submit Card',
                                onPressed: _amountNgn > 0 && _selectedImages.isNotEmpty
                                    ? _proceedToConfirmation
                                    : null,
                                backgroundColor: _themeColor,
                                icon: Icons.send,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard,
              size: 64,
              color: _themeColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No gift cards available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _fetchGiftCards,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: _themeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _themeColor.withOpacity(0.1),
            _themeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exchange Rate',
                style: TextStyle(fontSize: 14, color: AppColors.textColor),
              ),
              Text(
                '₦${_rate.toStringAsFixed(2)}/\$1',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: _themeColor.withOpacity(0.2)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You will receive',
                style: TextStyle(fontSize: 14, color: AppColors.textColor),
              ),
              Text(
                '₦${_amountNgn.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        // Upload buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectedImages.length < 5 ? _pickImages : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _themeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, color: _themeColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Gallery',
                        style: TextStyle(
                          color: _themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectedImages.length < 5 ? _takePicture : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _themeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: _themeColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Camera',
                        style: TextStyle(
                          color: _themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.memory(
                            _imageBytes[_selectedImages[index].path]!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.file(
                            File(_selectedImages[index].path),
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
                        decoration: BoxDecoration(
                          color: _themeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedImages.length} of 5 images selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _themeColor,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No images selected',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? _themeColor.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _themeColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _themeColor.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                giftCard['logo_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          giftCard['logo_url'],
                          height: 50,
                          width: 50,
                          errorBuilder: (_, __, ___) => Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: _themeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.card_giftcard,
                              size: 30,
                              color: _themeColor,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          size: 30,
                          color: _themeColor,
                        ),
                      ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    giftCard['name'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? _themeColor : AppColors.textColor,
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _countries.length,
      itemBuilder: (context, index) {
        final country = _countries[index];
        final countryData = country['country'];
        final isSelected = _selectedCountry?['id'] == country['id'];

        return GestureDetector(
          onTap: () => _onCountrySelected(country),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? _themeColor.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _themeColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _themeColor.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                countryData['flag_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          countryData['flag_url'],
                          height: 28,
                          width: 28,
                          errorBuilder: (_, __, ___) => Text(
                            countryData['code'] ?? '',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      )
                    : Text(
                        countryData['code'] ?? '',
                        style: const TextStyle(fontSize: 20),
                      ),
                const SizedBox(height: 6),
                Text(
                  countryData['code'] ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? _themeColor : AppColors.textColor,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _themeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _themeColor : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _themeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category == 'E-code' ? Icons.qr_code : Icons.credit_card,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Text(
              'No price ranges available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? _themeColor.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _themeColor : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _themeColor.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? _themeColor : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.white : Colors.grey.shade400,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      range['display_text'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? _themeColor : AppColors.textColor,
                      ),
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
}
