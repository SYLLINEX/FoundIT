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
  static const int _maxImages = 5;

  DateTime? selectedDate;
  String? selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _manualCategoryController =
      TextEditingController();

  // Multi-image support
  final List<File> _images = [];
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
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxImages images allowed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      imageQuality: 90,
    );

    if (pickedFile != null) {
      final newFile = File(pickedFile.path);
      setState(() {
        _images.add(newFile);
        _isAnalyzing = true;
      });

      await _runAiOnAllImages();
    }
  }

  /// Runs TFLite on ALL images in parallel and:
  ///   • averages all score vectors → stored as aiScoreVector (richer fingerprint)
  ///   • merges labels from all images → stored as aiLabels
  ///   • auto-selects category from the FIRST image (primary/intentional shot)
  Future<void> _runAiOnAllImages() async {
    try {
      // Run all images in parallel
      final allVectorsFutures =
          _images.map((f) => _tfliteService.getScoreVector(f));
      final allLabelsFutures =
          _images.map((f) => _tfliteService.getTopLabels(f, count: 5));

      final results = await Future.wait([
        Future.wait(allVectorsFutures),
        Future.wait(allLabelsFutures),
      ]);

      final allVectors = results[0] as List<List<double>>;
      final allLabels = results[1] as List<List<String>>;

      // Element-wise average of all score vectors
      final averaged = _averageVectors(allVectors);

      // Merge & de-duplicate labels from all images
      final merged =
          allLabels.expand((l) => l).toSet().toList();

      setState(() {
        _scoreVector = averaged;
        _detectedLabels = merged;

        // Category auto-select is based on the PRIMARY (first) image vector
        final primaryVector = allVectors.isNotEmpty ? allVectors[0] : <double>[];
        final primaryLabels = allLabels.isNotEmpty ? allLabels[0] : <String>[];

        double maxScore = primaryVector.isNotEmpty
            ? primaryVector.reduce((a, b) => a > b ? a : b)
            : 0.0;

        if (maxScore < 0.5 || primaryLabels.isEmpty) {
          selectedCategory = 'Other';
        } else {
          final primaryLabel = primaryLabels.first;
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

  /// Element-wise average of a list of equal-length vectors.
  List<double> _averageVectors(List<List<double>> vectors) {
    if (vectors.isEmpty) return [];
    final nonEmpty = vectors.where((v) => v.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return [];
    final length = nonEmpty.first.length;
    final sum = List<double>.filled(length, 0.0);
    for (final v in nonEmpty) {
      for (int i = 0; i < length; i++) {
        sum[i] += (i < v.length ? v[i] : 0.0);
      }
    }
    return sum.map((s) => s / nonEmpty.length).toList();
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
    if (_images.isNotEmpty) {
      setState(() => _isAnalyzing = true);
      _runAiOnAllImages();
    } else {
      setState(() {
        _scoreVector = [];
        _detectedLabels = [];
        selectedCategory = null;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.caretLeft,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        title: Text(
          'Report ${widget.reportType} Item',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
            // ── Multi-Image Upload Section ─────────────────────────────────
            _buildLabel('Item Photos'),
            const SizedBox(height: 4),
            Text(
              'Add up to $_maxImages photos. AI uses all photos for better matching.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            _buildImageRow(),
            const SizedBox(height: 8),

            // AI tip shown after at least one image
            if (_images.isNotEmpty && !_isAnalyzing) ...[
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
                      'AI analysed ${_images.length} photo${_images.length > 1 ? 's' : ''} to suggest a category. '
                      'You can change it manually if needed.',
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
            const SizedBox(height: 12),

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
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: const [
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
              backgroundColor: Theme.of(context).colorScheme.onSurface,
              foregroundColor: Theme.of(context).colorScheme.surface,
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
                          imageFiles: _images,
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

  // ── Multi-Image Row ─────────────────────────────────────────────────────────
  Widget _buildImageRow() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing image tiles
          ..._images.asMap().entries.map((entry) {
            final idx = entry.key;
            final file = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      file,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Primary badge
                  if (idx == 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF413F55).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(idx),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.x,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                  // Analyzing overlay on latest image
                  if (_isAnalyzing && idx == _images.length - 1)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: Colors.black38,
                          child: const Center(
                            child: FoundItLoadingIndicator(size: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          // "Add Photo" tile (hidden when at max)
          if (_images.length < _maxImages)
            GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.4),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIconsRegular.cameraPlus,
                      size: 28,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _images.isEmpty ? 'Add Photo' : 'Add More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '${_images.length}/$_maxImages',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
        hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    bool isComplete = _images.isNotEmpty &&
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
        hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                color: selectedDate != null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
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
