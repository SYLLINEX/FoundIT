import 'dart:io';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class AppErrorHandler {
  static String getMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred. Please try again.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'This email is already registered. Please log in.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        default:
          return 'Authentication error. Please try again.';
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'Service is currently unavailable. Please try again later.';
        case 'not-found':
          return 'The requested resource was not found.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        default:
          return 'A server error occurred. Please try again.';
      }
    }

    if (error is PlatformException) {
      switch (error.code) {
        case 'network_error':
          return 'Network error occurred. Please check your connection.';
        default:
          return 'An unexpected platform error occurred. Please try again.';
      }
    }

    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is FormatException) {
      return 'Data formatting error occurred. Please try again.';
    }

    if (error is TimeoutException) {
      return 'The connection has timed out. Please try again.';
    }

    // Check for explicit string message from our own "throw Exception('message')"
    final errorString = error.toString();
    if (errorString.startsWith('Exception: ')) {
      final message = errorString.replaceFirst('Exception: ', '').trim();
      // Only return it if it looks like a clean user-defined string without raw stack trace
      if (!message.contains('Firebase') && !message.contains('Exception') && !message.contains('Error:')) {
        return message;
      }
    }

    // Default generic message
    return 'An unexpected error occurred. Please try again later.';
  }
}
