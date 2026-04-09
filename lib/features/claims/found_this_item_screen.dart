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

  XFile? _photo;
  bool _isSubmitting = false;
  bool _isConfirmed = false;

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  Future<String?> _uploadPhoto(String userId) async {
    if (_photo == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('found_tips')
        .child(userId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(_photo!.path));
    return await ref.getDownloadURL();
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

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Upload photo if attached
      final photoUrl = await _uploadPhoto(user.uid);

      double? similarityScore;
      if (_photo != null) {
        final uploadedVec = await _tfliteService.getScoreVector(File(_photo!.path));
        if (uploadedVec.isNotEmpty && widget.lostItem.aiScoreVector.length == uploadedVec.length) {
          similarityScore = _cosineSimilarity(widget.lostItem.aiScoreVector, uploadedVec);
        } else {
          // Fallback label matching
          final labels = await _tfliteService.getTopLabels(File(_photo!.path));
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

      final claim = ClaimModel(
        claimId: const Uuid().v4(),
        itemId: widget.lostItem.itemId,
        claimantId: user.uid,           // finder
        ownerId: widget.lostItem.userId, // original lost-item reporter
        proofDesc: _descController.text.trim(),
        status: 'Pending',
        timestamp: DateTime.now(),
        claimType: 'found_tip',
        proofImageUrls: photoUrl != null ? [photoUrl] : [],
        similarityScore: similarityScore,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
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
              const Text(
                'Where did you find it?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.nightfall,
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
              const Text(
                'Additional details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.nightfall,
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

              // ── Photo (optional) ─────────────────────────────────────────
              const Text(
                'Photo proof (optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.nightfall,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhoto,
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_photo!.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
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
                              'Tap to upload a photo',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
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
