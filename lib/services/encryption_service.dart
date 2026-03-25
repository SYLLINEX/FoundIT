import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionService {
  static String get _appSalt => dotenv.env['ENCRYPTION_SALT'] ?? "FoundIT_Deepmind_Secure_Key_2026";

  static encrypt.Key _getKey(String roomId) {
    final bytes = utf8.encode(roomId + _appSalt);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes)); 
  }

  static String encryptMessage(String plainText, String roomId) {
    if (plainText.isEmpty) return plainText;
    try {
      final key = _getKey(roomId);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return "${iv.base64}:${encrypted.base64}";
    } catch (e) {
      return plainText; 
    }
  }

  static String decryptMessage(String encryptedPayload, String roomId) {
    if (encryptedPayload.isEmpty) return encryptedPayload;
    
    try {
      final key = _getKey(roomId);
      
      if (encryptedPayload.contains(':')) {
        final parts = encryptedPayload.split(':');
        final iv = encrypt.IV.fromBase64(parts[0]);
        final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        return encrypter.decrypt64(parts[1], iv: iv);
      } else {
        // Legacy fallback
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        return encrypter.decrypt64(encryptedPayload, iv: iv);
      }
    } catch (e) {
      return encryptedPayload; 
    }
  }
}
