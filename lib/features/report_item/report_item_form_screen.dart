import 'dart:io';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'tag_location_screen.dart';
import '../../services/tflite_service.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../widgets/found_it_loading_indicator.dart';

class ReportItemFormScreen extends StatefulWidget {
  final String reportType; // 'Lost' or 'Found'

  const ReportItemFormScreen({super.key, required this.reportType});

  @override
  State<ReportItemFormScreen> createState() => _ReportItemFormScreenState();
}

class _ReportItemFormScreenState extends State<ReportItemFormScreen> {
  DateTime? selectedDate;
  String? selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _manualCategoryController =
      TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TFLiteService _tfliteService = TFLiteService();
  bool _isAnalyzing = false;
  List<String> _detectedLabels = [];
  List<double> _scoreVector = [];

  // The 10 categories mirror exactly what the fine-tuned model outputs + Other
  static const List<String> _categories = [
    'Accessories',
    'Bag / Backpack',
    'Earphones / Earbuds',
    'ID / Card',
    'Keys',
    'Laptop / Tablet',
    'Mobile Phone',
    'Stationery',
    'Wallet / Purse',
    'Water Bottle / Tumbler',
    'Other',
  ];

  final _primaryDark = const Color(0xFF3B394D);
  final _bgColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
    _manualCategoryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _manualCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showAppConfirmationDialog<ImageSource>(
      context: context,
      title: 'Add Photo',
      message: 'Choose image source.',
      confirmText: 'Camera',
      cancelText: 'Gallery',
      confirmValue: ImageSource.camera,
      cancelValue: ImageSource.gallery,
    );

    if (source == null) return;
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality:
          80, // Forces JPEG conversion on iOS, fixing TFLite decoder errors with HEIC
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isAnalyzing = true;
      });

      try {
        // Run both in parallel — top labels + score vector
        final results = await Future.wait([
          _tfliteService.getTopLabels(_image!, count: 5),
          _tfliteService.getScoreVector(_image!),
        ]);

        final topLabels = results[0] as List<String>;
        final scoreVector = results[1] as List<double>;

        setState(() {
          _detectedLabels = topLabels;
          _scoreVector = scoreVector;

          // Find the highest confidence score
          double maxScore = 0.0;
          if (scoreVector.isNotEmpty) {
            maxScore = scoreVector.reduce(
              (curr, next) => curr > next ? curr : next,
            );
          }

          // Auto-select "Other" if max confidence is less than 50% or no labels met the 55% TFLite threshold
          if (maxScore < 0.5 || topLabels.isEmpty) {
            selectedCategory = 'Other';
          }
          // Direct match — model labels == dropdown options
          else {
            final String primaryLabel = topLabels.first;
            if (_categories.contains(primaryLabel)) {
              selectedCategory = primaryLabel;
            }
          }
        });
      } catch (e) {
        debugPrint('TFLite Error: $e');
      } finally {
        if (mounted) {
          setState(() => _isAnalyzing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryDark,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsRegular.caretLeft,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          'Report ${widget.reportType} Item',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 24.0,
          bottom: 100.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Upload Section
            _buildLabel('Item Image'),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                  image: _image != null
                      ? DecorationImage(
                          image: FileImage(_image!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.uploadSimple,
                              size: 24,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to Upload',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'JPG, PNG up to 5MB',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : _isAnalyzing
                    ? const Center(child: FoundItLoadingIndicator())
                    : const SizedBox(),
              ),
            ),
            const SizedBox(height: 24),

            // Item Title
            _buildLabel('Item Title'),
            const SizedBox(height: 8),
            _buildTextField(
              hint: 'e.g. Blue Car Keys',
              controller: _titleController,
            ),
            const SizedBox(height: 20),

            // Category
            _buildLabel('Category'),
            const SizedBox(height: 8),
            _buildDropdown(),
            const SizedBox(height: 8),

            if (_image != null && !_isAnalyzing) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsRegular.info,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Please verify the category. You can change it manually if the AI suggestion is incorrect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 12),
            ],

            if (selectedCategory == 'Other') ...[
              _buildLabel('Specify Category'),
              const SizedBox(height: 8),
              _buildTextField(
                hint: 'e.g. Umbrella, Glasses',
                controller: _manualCategoryController,
              ),
              const SizedBox(height: 20),
            ],

            // Description
            _buildLabel('Description'),
            const SizedBox(height: 8),
            _buildTextField(
              hint: 'Describe the item in detail...',
              maxLines: 4,
              controller: _descriptionController,
            ),
            const SizedBox(height: 20),

            // Date
            _buildLabel('Date'),
            const SizedBox(height: 8),
            _buildDateField(),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
            ),
            onPressed: _isFormComplete
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TagLocationScreen(
                          reportType: widget.reportType,
                          title: _titleController.text,
                          description: _descriptionController.text,
                          category: selectedCategory!,
                          manualCategory: selectedCategory == 'Other'
                              ? _manualCategoryController.text.trim()
                              : null,
                          date: selectedDate!,
                          imageFile: _image,
                          aiLabels: _detectedLabels,
                          aiScoreVector: _scoreVector,
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text(
              'Next: Tag Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    int maxLines = 1,
    TextEditingController? controller,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFE2E4EA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  bool get _isFormComplete {
    bool isComplete =
        _image != null &&
        _titleController.text.trim().isNotEmpty &&
        selectedCategory != null &&
        _descriptionController.text.trim().isNotEmpty &&
        selectedDate != null;

    if (selectedCategory == 'Other') {
      isComplete =
          isComplete && _manualCategoryController.text.trim().isNotEmpty;
    }

    return isComplete;
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCategory != null && _categories.contains(selectedCategory)
          ? selectedCategory
          : null,
      icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
      decoration: InputDecoration(
        hintText: 'Select a category',
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFE2E4EA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: _categories.map((e) {
        return DropdownMenuItem(value: e, child: Text(e));
      }).toList(),
      onChanged: (val) {
        setState(() {
          selectedCategory = val;
        });
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => selectedDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E4EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate != null
                  ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                  : 'Select Date',
              style: TextStyle(
                color: selectedDate != null ? Colors.black87 : Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const Icon(
              PhosphorIconsRegular.calendarBlank,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
