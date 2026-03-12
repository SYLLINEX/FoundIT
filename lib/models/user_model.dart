import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String role;
  final bool isAdmin;
  final String matricNo;
  final String phoneNum;
  final String profileImg;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    this.isAdmin = false,
    required this.matricNo,
    required this.phoneNum,
    required this.profileImg,
    required this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      uid: id,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      isAdmin: map['isAdmin'] ?? false,
      matricNo: map['matric_no'] ?? '',
      phoneNum: map['phone_num'] ?? '',
      profileImg: map['profile_img'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'role': role,
      'isAdmin': isAdmin,
      'matric_no': matricNo,
      'phone_num': phoneNum,
      'profile_img': profileImg,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}

