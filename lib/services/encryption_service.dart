import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionService {
  static String get _appSalt => dotenv.env['ENCRYPTION_SALT'] ?? (throw Exception('ENCRYPTION_SALT environment variable is required'));

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
      throw Exception("Encryption failed"); 
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
        throw Exception("Legacy decryption without IV is strictly prohibited.");
      }
    } catch (e) {
      throw Exception("Decryption failed"); 
    }
  }
}
