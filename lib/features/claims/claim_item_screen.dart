import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/tflite_service.dart';
import '../home/main_wrapper.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../core/utils/app_error_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ClaimItemScreen extends StatefulWidget {
  final ItemModel item;
  final String? initialLostReportId;

  const ClaimItemScreen({
    super.key,
    required this.item,
    this.initialLostReportId,
  });

  @override
  State<ClaimItemScreen> createState() => _ClaimItemScreenState();
}

class _ClaimItemScreenState extends State<ClaimItemScreen> {
  final TextEditingController _detailsController = TextEditingController();
  bool _isConfirmed = false;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _proofImages = [];
  final List<XFile> _itemImages = [];
  List<XFile> get _allImages => [..._itemImages, ..._proofImages];

  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final AIService _aiService = AIService();
  final TFLiteService _tfliteService = TFLiteService();

  bool _isSubmitting = false;
  bool _isCalculatingSimilarity = false;
  bool _isAnalyzingPhotos = false;
  ItemModel? _selectedLostReport;
  double? _similarityPercentage;
  double? _photoSimilarityPercentage;

  bool get _isPhotoSimilarityLow =>
      _photoSimilarityPercentage != null && _photoSimilarityPercentage! < 80.0;

  bool get _isSimilarityLow =>
      _aiService.isLowSimilarity(_similarityPercentage);

  bool get _canSubmit {
    return _isConfirmed &&
        _detailsController.text.trim().isNotEmpty &&
        !_isSubmitting;
  }

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tfliteService.initialize();
    _detailsController.addListener(() {
      if (!mounted) return;
      // Removed unnecessary setState to avoid rebuilding everything. Submit button can check controller or we use ValueListenableBuilder.
      // Wait, _canSubmit uses _detailsController.text.trim().isNotEmpty
      
      if (_selectedLostReport != null) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            _recalculateSimilarity();
          }
        });
      }

      setState(() {}); // They needed setState for _canSubmit. Will just debounce similarity instead of both.
    });

    if (widget.initialLostReportId != null &&
        widget.initialLostReportId!.isNotEmpty) {
      _loadInitialLostReport(widget.initialLostReportId!);
    }
  }

  Future<void> _loadInitialLostReport(String reportId) async {
    final doc = await FirebaseFirestore.instance
        .collection('items')
        .doc(reportId)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;

    final item = ItemModel.fromMap(doc.id, data);
    if (item.postType.toLowerCase() != 'lost') return;

    setState(() {
      _selectedLostReport = item;
    });
    await _recalculateSimilarity();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tfliteService.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('What type of photo?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.camera, color: Colors.indigo),
                  title: const Text('Picture of the Item'),
                  subtitle: const Text('AI will scan these to calculate similarity match.'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickItemImages();
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.receipt, color: Colors.indigo),
                  title: const Text('Ownership Proof'),
                  subtitle: const Text('Receipts, serial numbers, packaging, etc.'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProofImages();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickProofImages() async {
    final pickedFiles = await _imagePicker.pickMultiImage(imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (pickedFiles.isNotEmpty) setState(() => _proofImages.addAll(pickedFiles));
  }

  Future<void> _pickItemImages() async {
    final pickedFiles = await _imagePicker.pickMultiImage(imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _itemImages.addAll(pickedFiles);
        _isAnalyzingPhotos = true;
      });
      await _analyzeItemImages();
    }
  }

  Future<void> _analyzeItemImages() async {
    if (_itemImages.isEmpty) {
      setState(() {
        _photoSimilarityPercentage = null;
        _isAnalyzingPhotos = false;
      });
      return;
    }

    // Gather score vectors from all submitted item photos.
    // Average them to get a representative embedding for this claim.
    List<List<double>> allVectors = [];
    for (var file in _itemImages) {
      final vec = await _tfliteService.getScoreVector(File(file.path));
      if (vec.isNotEmpty) allVectors.add(vec);
    }

    if (allVectors.isEmpty) {
      setState(() {
        _photoSimilarityPercentage = 0.0;
        _isAnalyzingPhotos = false;
      });
      return;
    }

    // Average the vectors element-wise.
    final int vecLen = allVectors.first.length;
    final List<double> avgVector = List.filled(vecLen, 0.0);
    for (final vec in allVectors) {
      for (int i = 0; i < vecLen; i++) {
        avgVector[i] += vec[i];
      }
    }
    for (int i = 0; i < vecLen; i++) {
      avgVector[i] /= allVectors.length;
    }

    // Compute cosine similarity directly between stored vector and photo vector.
    // Do NOT use compareLostReportToClaim() here — that includes text/location
    // which would inflate the score since we're comparing the item to itself.
    double score;
    if (widget.item.aiScoreVector.isNotEmpty &&
        widget.item.aiScoreVector.length == avgVector.length) {
      score = _cosineSimilarity(widget.item.aiScoreVector, avgVector);
    } else {
      // Fallback: label Jaccard
      final Set<String> detectedLabels = {};
      for (var file in _itemImages) {
        final labels = await _tfliteService.getTopLabels(File(file.path));
        detectedLabels.addAll(labels);
      }
      if (widget.item.aiLabels.isEmpty || detectedLabels.isEmpty) {
        score = 0.0;
      } else {
        final lowerItem = widget.item.aiLabels.map((e) => e.toLowerCase().trim()).toSet();
        final lowerDetected = detectedLabels.map((e) => e.toLowerCase().trim()).toSet();
        final intersection = lowerItem.intersection(lowerDetected).length;
        final union = lowerItem.union(lowerDetected).length;
        score = union == 0 ? 0.0 : (intersection / union) * 100;
      }
    }

    setState(() {
      _photoSimilarityPercentage = score.clamp(0.0, 100.0);
      _isAnalyzingPhotos = false;
    });
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot  += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return ((dot / (magA * magB)) * 100).clamp(0.0, 100.0);
  }

  Future<List<String>> _uploadProofImages(String userId) async {
    List<String> uploadedUrls = [];
    try {
      for (XFile image in _allImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('claim_proofs')
            .child(userId)
            .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

        await ref.putFile(File(image.path));
        String url = await ref.getDownloadURL();
        uploadedUrls.add(url);
      }
    } catch (e) {
      debugPrint('Error uploading proof images: $e');
    }
    return uploadedUrls;
  }

  Future<void> _selectLostReport() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    final selected = await showModalBottomSheet<ItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Minimalist Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select a LOST Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.obsidian,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('items')
                      .where('user_id', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: FoundItLoadingIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final reports = docs
                        .map(
                          (doc) => ItemModel.fromMap(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .where((item) {
                          if (item.postType.toLowerCase() != 'lost') {
                            return false;
                          }
                          final normalized = item.status.toLowerCase();
                          return normalized != 'resolved' &&
                              normalized != 'rejected';
                        })
                        .toList()
                      ..sort(
                        (a, b) => b.timestamp.compareTo(a.timestamp),
                      );

                    if (reports.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.article,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No active LOST reports found.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create a LOST report first if you want to link one to this claim.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final isSelected =
                            _selectedLostReport?.itemId == report.itemId;

                        return GestureDetector(
                          onTap: () => Navigator.pop(context, report),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.indigo.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.indigo.shade200
                                    : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: [
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: report.imageUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: report.imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Shimmer.fromColors(
                                              baseColor: Colors.grey[300]!,
                                              highlightColor: Colors.grey[100]!,
                                              child: Container(color: Colors.white),
                                            ),
                                            errorWidget: (context, url, error) => const Icon(
                                              PhosphorIconsRegular.imageBroken,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          PhosphorIconsRegular.imageBroken,
                                          color: Colors.grey,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        report.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: AppColors.obsidian,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${report.category} • ${report.status}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? PhosphorIconsRegular.checkCircle
                                      : PhosphorIconsRegular.caretRight,
                                  color: isSelected
                                      ? Colors.indigo
                                      : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedLostReport = selected;
    });
    await _recalculateSimilarity();
  }

  Future<void> _recalculateSimilarity() async {
    final linked = _selectedLostReport;
    if (linked == null) {
      if (!mounted) return;
      setState(() => _similarityPercentage = null);
      return;
    }

    setState(() => _isCalculatingSimilarity = true);

    final similarity = _aiService.compareLostReportToClaim(
      linkedLostReport: linked,
      claimTargetItem: widget.item,
      claimDescription: _detailsController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _similarityPercentage = similarity;
      _isCalculatingSimilarity = false;
    });
  }

  Future<bool> _confirmLowSimilaritySubmission() async {
    final result = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Submit Claim?',
      message:
          'Low AI similarity (< ${AIService.lowSimilarityThreshold.toStringAsFixed(0)}%). You can add more proof photos first.',
      confirmText: 'Submit Anyway',
      cancelText: 'Review Claim',
      confirmColor: AppColors.statusPending,
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretLeft,
              color: AppColors.nightfall),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Ownership',
          style: TextStyle(
            color: AppColors.nightfall,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Reference card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  if (widget.item.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: widget.item.imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.mist,
                          child: const Icon(PhosphorIconsRegular.imageBroken),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.statusFound.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'FOUND',
                            style: TextStyle(
                              color: AppColors.statusFound,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.nightfall,
                          ),
                        ),
                        Text(
                          widget.item.category,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Info banner ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.info,
                      color: Colors.blue.shade400, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your claim will be reviewed. Once approved, you can chat with the finder to arrange the return.',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Details Input Section ────────────────────────────────────
            Text.rich(
              const TextSpan(
                text: 'Claim Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.nightfall,
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Describe details only the owner would know.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _detailsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Example: ID card inside, sticker near zip, small scratch on corner.',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 28),

            // ── Linked Report Section ────────────────────────────────────
            const Text(
              'Linked LOST Report',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.nightfall,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Attach your existing report for AI comparison.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_selectedLostReport == null)
              GestureDetector(
                onTap: _selectLostReport,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(PhosphorIconsRegular.link, color: Colors.grey.shade400, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to link a LOST report',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLostReport!.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.nightfall,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedLostReport!.category} • ${_selectedLostReport!.status}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedLostReport = null;
                                _similarityPercentage = null;
                              });
                            },
                            icon: const Icon(PhosphorIconsRegular.x, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF2F2F6)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _isCalculatingSimilarity
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Analyzing match...', style: TextStyle(color: Colors.grey)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'AI Similarity Match',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      _similarityPercentage == null
                                          ? '--%'
                                          : '${_similarityPercentage!.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isSimilarityLow ? Colors.orange.shade700 : Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: (_similarityPercentage ?? 0) / 100,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _isSimilarityLow ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                ),
                                if (_isSimilarityLow)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'Low similarity. Consider adding photos below to strengthen your claim.',
                                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // ── Photos Section ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supporting Photos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.nightfall,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add images of the item or ownership proof.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (_allImages.isNotEmpty)
                  TextButton(
                    onPressed: _showImagePickerOptions,
                    child: const Text('Add More'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_allImages.isEmpty)
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(PhosphorIconsRegular.image, color: Colors.grey.shade400, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload photos',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_itemImages.isNotEmpty) _buildImageList(_itemImages, true),
              if (_proofImages.isNotEmpty) _buildImageList(_proofImages, false),
            ],

            if (_itemImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _isAnalyzingPhotos 
                ? const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Analyzing photos with AI...', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isPhotoSimilarityLow ? Colors.orange.shade200 : Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Photo Match Score', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_photoSimilarityPercentage?.toStringAsFixed(0) ?? 0}%',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _isPhotoSimilarityLow ? Colors.orange.shade700 : Colors.green.shade600)
                            ),
                          ],
                        ),
                        if (_isPhotoSimilarityLow) ...[
                          const SizedBox(height: 8),
                          Text('Match is below 80%. Please provide highly detailed descriptions above to prove ownership.', style: TextStyle(color: Colors.orange.shade800, height: 1.4, fontSize: 12)),
                        ],
                      ]
                    )
                  )
            ],
            const SizedBox(height: 32),

            // ── Confirmation Checkbox ────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _isConfirmed = !_isConfirmed),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isConfirmed ? Colors.blue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isConfirmed ? Colors.blue.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isConfirmed ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.circle,
                      color: _isConfirmed ? Colors.blue : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'I confirm this claim is truthful and I am the rightful owner.',
                        style: TextStyle(
                          color: AppColors.nightfall,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submitClaim : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.nightfall,
                  disabledBackgroundColor: AppColors.nightfall.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting 
                    ? const FoundItLoadingIndicator()
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsRegular.paperPlaneTilt,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submit Claim',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _submitClaim() async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    if (_selectedLostReport != null) {
      await _recalculateSimilarity();
    }

    if (_isSimilarityLow) {
      final shouldProceed =
          await _confirmLowSimilaritySubmission();
      if (!shouldProceed) {
        return;
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: FoundItLoadingIndicator()),
    );

    try {
      // Upload proof images if any were selected
      List<String> proofImageUrls = [];
      if (_allImages.isNotEmpty) {
        proofImageUrls = await _uploadProofImages(uid);
      }

      final claim = ClaimModel(
        claimId: const Uuid().v4(),
        itemId: widget.item.itemId,
        claimantId: uid,
        ownerId: widget.item.userId,
        status: 'Pending',
        proofDesc: _detailsController.text.trim(),
        timestamp: DateTime.now(),
        linkedLostReportId: _selectedLostReport?.itemId,
        similarityScore: _similarityPercentage,
      );

      // Add proof images to claim if available
      if (proofImageUrls.isNotEmpty) {
        claim.proofImageUrls = proofImageUrls;
      }

      await _dbService.submitClaim(claim);

      await _notificationService.createNotification(
        userId: widget.item.userId,
        title: 'Someone found your report',
        body:
            'A user submitted a claim for "${widget.item.title}". Review will follow.',
        type: 'report_found',
        relatedItemId: widget.item.itemId,
        data: {'claim_id': claim.claimId},
      );

      await _notificationService.notifyAdmins(
        title: 'New claim pending review',
        body:
            'A claim for "${widget.item.title}" was submitted and needs verification.',
        type: 'admin_alert',
        relatedItemId: widget.item.itemId,
        data: {'claim_id': claim.claimId},
      );

      if (mounted) {
        Navigator.pop(context); // close loading
        _showSuccessSheet();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        final errorMsg = AppErrorHandler.getMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.statusFound.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.checkCircle,
                color: AppColors.statusFound,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Claim Submitted!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.nightfall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your ownership claim is under review by an admin.\n\n'
              'If approved, you will be notified and a chat will open '
              'so you can arrange the return with the finder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainWrapper(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusFound,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageList(List<XFile> images, bool isItemPhoto) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(isItemPhoto ? 'Item Photos (AI Scanned)' : 'Proof Photos (Receipts, etc.)', 
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.indigo)),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(images[index].path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            images.removeAt(index);
                            if (isItemPhoto) _analyzeItemImages();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            PhosphorIconsRegular.x,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}