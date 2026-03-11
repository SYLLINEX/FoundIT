import 'package:flutter/material.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  String reportType = 'Lost';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Lost', label: Text('I Lost Something')),
                ButtonSegment(value: 'Found', label: Text('I Found Something')),
              ],
              selected: {reportType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => reportType = newSelection.first);
              },
            ),
            const SizedBox(height: 24),

            // Image Upload & AI Placeholder
            InkWell(
              onTap: () {
                // TODO: Implement ImagePicker & TensorFlow Lite matching
              },
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Upload Image (AI Auto-Tagging)', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form Fields
            TextFormField(decoration: const InputDecoration(labelText: 'Item Title')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['Electronics', 'Wallet/ID', 'Keys', 'Clothing', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {},
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description & Distinct Marks'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
              title: const Text('Pin Location on Map'),
              subtitle: const Text('Tap to set exact coordinates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted for SRC verification!')),
                );
              },
              child: const Text('Submit Report'),
            )
          ],
        ),
      ),
    );
  }
}