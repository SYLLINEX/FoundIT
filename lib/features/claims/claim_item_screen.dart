import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../home/main_wrapper.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../widgets/found_it_loading_indicator.dart';

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
  final List<XFile> _selectedImages = [];
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final AIService _aiService = AIService();

  bool _isSubmitting = false;
  bool _isCalculatingSimilarity = false;
  ItemModel? _selectedLostReport;
  double? _similarityPercentage;

  bool get _isSimilarityLow =>
      _aiService.isLowSimilarity(_similarityPercentage);

  bool get _canSubmit {
    return _isConfirmed &&
        _detailsController.text.trim().isNotEmpty &&
        !_isSubmitting;
  }

  @override
  void initState() {
    super.initState();
    _detailsController.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (_selectedLostReport != null) {
        _recalculateSimilarity();
      }
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
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles);
      });
    }
  }

  Future<List<String>> _uploadProofImages(String userId) async {
    List<String> uploadedUrls = [];
    try {
      for (XFile image in _selectedImages) {
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
                                Icons.article_outlined,
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
                                          child: Image.network(
                                            report.imageUrl,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.image_not_supported_outlined,
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
                                      ? Icons.check_circle
                                      : Icons.chevron_right,
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.obsidian, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Verify Ownership',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.obsidian,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share key details, link a LOST report, and add optional photos to strengthen your verification.',
              style: TextStyle(
                color: Color(0xFF6B6A7C),
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Details Input Section
            _buildSectionTitle('Claim Details', 'Describe details only the owner would know.'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _detailsController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Example: ID card inside, sticker near zip, small scratch on corner.',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Linked Report Section
            _buildSectionTitle('Linked LOST Report', 'Attach your existing report for AI comparison.'),
            const SizedBox(height: 12),
            if (_selectedLostReport == null)
              GestureDetector(
                onTap: _selectLostReport,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade100, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.link_rounded, color: Colors.indigo, size: 28),
                      SizedBox(height: 8),
                      Text(
                        'Tap to link a LOST report',
                        style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedLostReport!.category} • ${_selectedLostReport!.status}',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                            icon: const Icon(Icons.close, color: Colors.grey),
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
                                        fontWeight: FontWeight.w800,
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
            const SizedBox(height: 32),

            // Photos Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSectionTitle('Supporting Photos', 'Add images of the item or ownership proof.')),
                if (_selectedImages.isNotEmpty)
                  TextButton(
                    onPressed: _pickImages,
                    child: const Text('Add More'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Tap to upload photos',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_selectedImages[index].path),
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
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
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
            const SizedBox(height: 32),

            // Confirmation Checkbox
            GestureDetector(
              onTap: () => setState(() => _isConfirmed = !_isConfirmed),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isConfirmed ? Colors.indigo.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isConfirmed ? Colors.indigo.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isConfirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isConfirmed ? Colors.indigo : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'I confirm this claim is truthful and I am the rightful owner.',
                        style: TextStyle(
                          color: AppColors.obsidian,
                          fontSize: 13,
                          height: 1.4,
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
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _canSubmit
              ? () async {
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
                    if (_selectedImages.isNotEmpty) {
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
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainWrapper(),
                        ),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Claim submitted successfully!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit claim: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.nightfall,
            disabledBackgroundColor: AppColors.nightfall.withOpacity(0.3),
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSubmitting 
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Text(
                  'Submit Claim',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.obsidian,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF7B7A8D), fontSize: 13),
        ),
      ],
    );
  }
}