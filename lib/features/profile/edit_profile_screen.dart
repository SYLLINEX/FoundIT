import 'dart:io';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import 'package:path/path.dart' as p;
import '../../widgets/found_it_loading_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_error_handler.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel userModel;

  const EditProfileScreen({super.key, required this.userModel});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _phoneNumController;
  late TextEditingController _matricNoController;

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.userModel.username,
    );
    _phoneNumController = TextEditingController(
      text: widget.userModel.phoneNum,
    );
    _matricNoController = TextEditingController(
      text: widget.userModel.matricNo,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneNumController.dispose();
    _matricNoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl = widget.userModel.profileImg;

      if (_imageFile != null) {
        final ext = p.extension(_imageFile!.path);
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${widget.userModel.uid}$ext');

        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userModel.uid)
          .set({
            'username': _usernameController.text.trim(),
            'phone_num': _phoneNumController.text.trim(),
            'matric_no': _matricNoController.text.trim(),
            'profile_img': imageUrl,
            'email': widget.userModel.email, // Preserve email just in case
          }, SetOptions(merge: true));

      // Update FirebaseAuth profile to keep it in sync and prevent UI flicker
      await FirebaseAuth.instance.currentUser?.updateProfile(
        displayName: _usernameController.text.trim(),
        photoURL: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: FoundItLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (widget.userModel.profileImg.isNotEmpty
                                  ? NetworkImage(widget.userModel.profileImg)
                                        as ImageProvider
                                  : null),
                        child:
                            _imageFile == null &&
                                widget.userModel.profileImg.isEmpty
                            ? const Icon(PhosphorIconsRegular.camera, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change profile picture',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: widget.userModel.email,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        filled: true,
                        prefixIcon: Icon(
                          PhosphorIconsRegular.envelopeSimple,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                      readOnly: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        label: Text.rich(
                          const TextSpan(
                            text: 'Username',
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumController,
                      decoration: InputDecoration(
                        label: Text.rich(
                          const TextSpan(
                            text: 'Phone Number',
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a phone number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matricNoController,
                      decoration: InputDecoration(
                        label: Text.rich(
                          const TextSpan(
                            text: 'Matric No',
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your Matric No' : null,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
