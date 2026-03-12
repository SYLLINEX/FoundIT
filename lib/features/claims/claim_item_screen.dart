import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../home/main_wrapper.dart';
import 'package:uuid/uuid.dart';

class ClaimItemScreen extends StatefulWidget {
  final ItemModel item;

  const ClaimItemScreen({super.key, required this.item});

  @override
  State<ClaimItemScreen> createState() => _ClaimItemScreenState();
}

class _ClaimItemScreenState extends State<ClaimItemScreen> {
  final TextEditingController _detailsController = TextEditingController();
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF413F54),
        title: const Text('Claim Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
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
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
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
                hintText: "e.g. My student ID ending with 1234 is inside, there's a scratch on the bottom left corner...",
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I confirm that I am the rightful owner of this item. I understand that submitting false claims may lead to disciplinary action.',
                      style: TextStyle(color: AppColors.dusk, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        color: const Color(0xFFF2F2F6),
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _isConfirmed && _detailsController.text.isNotEmpty ? () async {
            final authService = AuthService();
            final dbService = DatabaseService();
            final uid = authService.currentUser?.uid;
            
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first.')));
              return;
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

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );

            try {
              await dbService.submitClaim(claim);
              if (mounted) {
                Navigator.pop(context); // close loading
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainWrapper()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted successfully!')));
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context); // close loading
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit claim: $e')));
              }
            }
          } : null,
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
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
