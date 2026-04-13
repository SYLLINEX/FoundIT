import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/item_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_error_handler.dart';

class EditReportScreen extends StatefulWidget {
  final ItemModel item;

  const EditReportScreen({super.key, required this.item});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _specificLocationController;

  late String _selectedCategory;
  late String _selectedStatus;

  final List<String> _categories = [
    'Electronics',
    'Personal',
    'Accessories',
    'Documents',
    'Others',
  ];

  final List<String> _statuses = ['Pending for Approval', 'Open', 'Resolved'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _specificLocationController = TextEditingController(
      text: widget.item.specificLocation ?? '',
    );

    _selectedCategory = widget.item.category.isNotEmpty
        ? widget.item.category
        : 'Others';
    if (!_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory);
    }

    _selectedStatus = widget.item.status.isNotEmpty
        ? widget.item.status
        : 'Open';
    // Match letter casing or normalize if needed, but adding directly works for existing exact string.
    if (!_statuses.contains(_selectedStatus)) {
      _statuses.add(_selectedStatus);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _specificLocationController.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection('items')
            .doc(widget.item.itemId)
            .update({
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'specific_location': _specificLocationController.text.trim(),
              'category': _selectedCategory,
              'status': _selectedStatus,
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report updated successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          final errorMessage = AppErrorHandler.getMessage(e);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Report'),
        backgroundColor: AppColors.nightfall,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  label: Text.rich(
                    const TextSpan(
                      text: 'Title',
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  label: Text.rich(
                    const TextSpan(
                      text: 'Description',
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specificLocationController,
                decoration: const InputDecoration(
                  labelText: 'Specific Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  label: Text.rich(
                    const TextSpan(
                      text: 'Category',
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  label: Text.rich(
                    const TextSpan(
                      text: 'Status',
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: _statuses.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) _selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.nightfall,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
