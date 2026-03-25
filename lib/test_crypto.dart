import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  final plainText = "Hello World";
  final roomId = "room123";
  final _appSalt = dotenv.env['ENCRYPTION_SALT'] ?? "FoundIT_Deepmind_Secure_Key_2026";

  final bytes = utf8.encode(roomId + _appSalt);
  final digest = sha256.convert(bytes);
  final key = encrypt.Key(Uint8List.fromList(digest.bytes)); 
  
  final iv = encrypt.IV.fromLength(16); 
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  
  final encrypted = encrypter.encrypt(plainText, iv: iv);
  print(encrypted.base64);
  
  final decrypted = encrypter.decrypt64(encrypted.base64, iv: iv);
  print(decrypted);
}
