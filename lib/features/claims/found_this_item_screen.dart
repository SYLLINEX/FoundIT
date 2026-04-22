import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/tflite_service.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/app_confirmation_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/app_error_handler.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/ai_service.dart';

import '../../utils/image_helper.dart';

class FoundThisItemScreen extends StatefulWidget {
  final ItemModel lostItem;

  const FoundThisItemScreen({super.key, required this.lostItem});

  @override
  State<FoundThisItemScreen> createState() => _FoundThisItemScreenState();
}

class _FoundThisItemScreenState extends State<FoundThisItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final TFLiteService _tfliteService = TFLiteService();

  List<XFile> _photos = [];
  bool _isSubmitting = false;
  bool _isConfirmed = false;

  ItemModel? _selectedFoundReport;
  double? _similarityPercentage;
  bool _isCalculatingSimilarity = false;
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _descController.addListener(() {
      if (!mounted) return;
      if (_selectedFoundReport != null) {
        _recalculateSimilarity();
      }
    });
  }

  Future<void> _selectFoundReport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
                    'Select a FOUND Report',
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
                          if (item.postType.toLowerCase() != 'found') {
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
                                'No active FOUND reports found.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create a FOUND report first if you want to link one to this report.',
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
                            _selectedFoundReport?.itemId == report.itemId;

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
      _selectedFoundReport = selected;
    });
    await _recalculateSimilarity();
  }

  Future<void> _recalculateSimilarity() async {
    final linked = _selectedFoundReport;
    if (linked == null) {
      if (!mounted) return;
      setState(() => _similarityPercentage = null);
      return;
    }

    setState(() => _isCalculatingSimilarity = true);

    final similarity = _aiService.compareLostReportToClaim(
      linkedLostReport: widget.lostItem,
      claimTargetItem: linked,
      claimDescription: _descController.text.trim(),
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
      title: 'Submit Report?',
      message:
          'Low AI similarity (< ${AIService.lowSimilarityThreshold.toStringAsFixed(0)}%). You can add more proof photos or details first.',
      confirmText: 'Submit Anyway',
      cancelText: 'Review',
      confirmColor: AppColors.statusPending,
    );

    return result ?? false;
  }

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    if (picked.isNotEmpty) {
      final normalizedFiles = await Future.wait(picked.map((f) => ImageHelper.normalizeImage(f)));
      setState(() => _photos.addAll(normalizedFiles));
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<List<String>> _uploadPhotos(String userId) async {
    if (_photos.isEmpty) return [];
    List<String> urls = [];
    for (var photo in _photos) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('found_tips')
          .child(userId)
          .child('${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.jpg');
      await ref.putFile(File(photo.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
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
    return ((dot / (sqrt(magA) * sqrt(magB))) * 100).clamp(0.0, 100.0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one photo proof.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      if (_similarityPercentage != null && _similarityPercentage! < AIService.lowSimilarityThreshold) {
        final confirmed = await _confirmLowSimilaritySubmission();
        if (!confirmed) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Upload photos
      final photoUrls = await _uploadPhotos(user.uid);

      double? similarityScore;
      if (_photos.isNotEmpty) {
        final uploadedVec = await _tfliteService.getScoreVector(File(_photos.first.path));
        if (uploadedVec.isNotEmpty && widget.lostItem.aiScoreVector.length == uploadedVec.length) {
          similarityScore = _cosineSimilarity(widget.lostItem.aiScoreVector, uploadedVec);
        } else {
          // Fallback label matching
          final labels = await _tfliteService.getTopLabels(File(_photos.first.path));
          final detectedLabels = labels.toSet();
          if (widget.lostItem.aiLabels.isEmpty || detectedLabels.isEmpty) {
            similarityScore = 0.0;
          } else {
            final lowerItem = widget.lostItem.aiLabels.map((e) => e.toLowerCase().trim()).toSet();
            final lowerDetected = detectedLabels.map((e) => e.toLowerCase().trim()).toSet();
            final intersection = lowerItem.intersection(lowerDetected).length;
            final union = lowerItem.union(lowerDetected).length;
            similarityScore = union == 0 ? 0.0 : (intersection / union) * 100;
          }
        }
      }

      final scoreToSave = similarityScore ?? _similarityPercentage;

      final claim = ClaimModel(
        claimId: const Uuid().v4(),
        itemId: widget.lostItem.itemId,
        claimantId: user.uid,           // finder
        ownerId: widget.lostItem.userId, // original lost-item reporter
        proofDesc: _descController.text.trim(),
        status: 'Pending',
        timestamp: DateTime.now(),
        claimType: 'found_tip',
        proofImageUrls: photoUrls,
        similarityScore: scoreToSave,
        linkedLostReportId: _selectedFoundReport?.itemId,
      );

      await _db.submitClaim(claim);

      // Notify admins to review
      await _notificationService.notifyAdmins(
        title: 'Someone found a lost item!',
        body:
            'A user reported finding "${widget.lostItem.title}". Please review.',
        type: 'found_tip_pending',
        relatedItemId: widget.lostItem.itemId,
      );

      if (mounted) {
        _showSuccessSheet();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = AppErrorHandler.getMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              'Report Submitted!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.nightfall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for being helpful! An admin will review your report.\n\n'
              'If approved, the item owner will be notified and a chat will '
              'open so you can arrange the return.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                    ..pop() // sheet
                    ..pop() // this screen
                    ..pop(); // item details
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

  @override
  Widget build(BuildContext context) {
    final item = widget.lostItem;

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
          'I Found This Item',
          style: TextStyle(
            color: AppColors.nightfall,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Reference card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.statusFound.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    if (item.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
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
                              color: AppColors.statusLost.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LOST',
                              style: TextStyle(
                                color: AppColors.statusLost,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.nightfall,
                            ),
                          ),
                          Text(
                            item.category,
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
                        'Your report will be reviewed by an admin. Once approved, the item owner will be notified and a chat will open.',
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

              // ── Where did you find it? ───────────────────────────────────
              Text.rich(
                const TextSpan(
                  text: 'Where did you find it?',
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Near UNIMAS library main entrance',
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
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please describe the location' : null,
              ),
              const SizedBox(height: 20),

              // ── Additional details ───────────────────────────────────────
              Text.rich(
                const TextSpan(
                  text: 'Additional details',
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Describe the item condition, any identifying marks, when you found it...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 10)
                        ? 'Please provide some details (min 10 chars)'
                        : null,
              ),
              const SizedBox(height: 20),

              // ── Photo (required) ─────────────────────────────────────────
              const Text(
                'Photo proof (required)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.nightfall,
                ),
              ),
              const SizedBox(height: 8),
              if (_photos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      return GestureDetector(
                        onTap: _pickPhotos,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid),
                          ),
                          child: Icon(PhosphorIconsRegular.plus,
                              color: Colors.grey.shade400, size: 32),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_photos[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              else
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.shade300,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.image,
                            color: Colors.grey.shade400, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload photos',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 28),

              // ── Linked Report Section ────────────────────────────────────
              const Text(
                'Link to your FOUND report (optional)',
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
              if (_selectedFoundReport == null)
                GestureDetector(
                  onTap: _selectFoundReport,
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
                          'Tap to link a FOUND report',
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
                                    _selectedFoundReport!.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.nightfall,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedFoundReport!.category} • ${_selectedFoundReport!.status}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFoundReport = null;
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
                                  SizedBox(width: 8),
                                  Text('Calculating AI similarity...',
                                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              )
                            : _similarityPercentage != null
                                ? Row(
                                    children: [
                                      Icon(
                                        _similarityPercentage! >= 80.0
                                            ? PhosphorIconsRegular.checkCircle
                                            : PhosphorIconsRegular.warning,
                                        color: _similarityPercentage! >= 80.0
                                            ? AppColors.statusResolved
                                            : Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'AI Match Score: ${_similarityPercentage!.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: _similarityPercentage! >= 80.0
                                                ? AppColors.statusResolved
                                                : Colors.orange.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Requires description text for AI score',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                      ),
                    ],
                  ),
                ),
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
                          'I confirm that I found this item and the details are accurate.',
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
                  onPressed: (_isSubmitting || !_isConfirmed) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusFound,
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
                              'Submit Report',
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
      ),
    );
  }
}

