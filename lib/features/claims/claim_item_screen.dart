import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../home/main_wrapper.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/found_it_loading_indicator.dart';

class ClaimItemScreen extends StatefulWidget {
  final ItemModel item;

  const ClaimItemScreen({super.key, required this.item});

  @override
  State<ClaimItemScreen> createState() => _ClaimItemScreenState();
}

class _ClaimItemScreenState extends State<ClaimItemScreen> {
  final TextEditingController _detailsController = TextEditingController();
  bool _isConfirmed = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile>? _selectedImages = [];

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
        _selectedImages!.addAll(pickedFiles);
      });
    }
  }

  Future<List<String>> _uploadProofImages(String userId) async {
    List<String> uploadedUrls = [];
    try {
      for (XFile image in _selectedImages!) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF413F54),
        title: const Text(
          'Claim Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Proof of Ownership',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.obsidian,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To ensure items are returned to their rightful owners, please provide specific details that only the owner would know.',
                    style: TextStyle(color: Color(0xFF6B6A7C), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Describe identifying features',
              style: TextStyle(
                color: AppColors.dusk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    "e.g. My student ID ending with 1234 is inside, there's a scratch on the bottom left corner...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFE5E5EA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Additional Proof (Optional)',
              style: TextStyle(
                color: AppColors.dusk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload pictures to strengthen your claim',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nightfall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Examples: S/N of items • Latest pictures of the missing item • Your Lost Item reports • Any evidence of ownership',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((_selectedImages?.length ?? 0) > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedImages!.length} image(s) selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages!.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_selectedImages![index].path),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImages!.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
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
                        const SizedBox(height: 12),
                      ],
                    ),
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add Pictures'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepLavender,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _isConfirmed,
                    onChanged: (val) {
                      setState(() {
                        _isConfirmed = val ?? false;
                      });
                    },
                    activeColor: AppColors.nightfall,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I confirm that I am the rightful owner of this item. I understand that submitting false claims may lead to disciplinary action.',
                    style: TextStyle(
                      color: AppColors.dusk,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        color: const Color(0xFFF2F2F6),
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _isConfirmed && _detailsController.text.isNotEmpty
              ? () async {
                  final authService = AuthService();
                  final dbService = DatabaseService();
                  final notificationService = NotificationService();
                  final uid = authService.currentUser?.uid;

                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in first.')),
                    );
                    return;
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
                    if (_selectedImages != null && _selectedImages!.isNotEmpty) {
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
                    );
                    
                    // Add proof images to claim if available
                    if (proofImageUrls.isNotEmpty) {
                      claim.proofImageUrls = proofImageUrls;
                    }

                    await dbService.submitClaim(claim);

                    await notificationService.createNotification(
                      userId: widget.item.userId,
                      title: 'Someone found your report',
                      body:
                          'A user submitted a claim for "${widget.item.title}". Review will follow.',
                      type: 'report_found',
                      relatedItemId: widget.item.itemId,
                      data: {'claim_id': claim.claimId},
                    );

                    await notificationService.notifyAdmins(
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
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepLavender,
            disabledBackgroundColor: AppColors.deepLavender.withOpacity(0.5),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Submit Claim Request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
