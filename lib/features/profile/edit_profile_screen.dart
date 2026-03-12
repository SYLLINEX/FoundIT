import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'package:path/path.dart' as p;

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
    _usernameController = TextEditingController(text: widget.userModel.username);
    _phoneNumController = TextEditingController(text: widget.userModel.phoneNum);
    _matricNoController = TextEditingController(text: widget.userModel.matricNo);
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
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
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                        child: _imageFile == null &&
                                widget.userModel.profileImg.isEmpty
                            ? const Icon(Icons.camera_alt, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to change profile picture',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: widget.userModel.email,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        fillColor: Colors.grey.shade200,
                        filled: true,
                        prefixIcon: const Icon(Icons.email, color: Colors.grey),
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a phone number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matricNoController,
                      decoration: const InputDecoration(labelText: 'Matric No'),
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
