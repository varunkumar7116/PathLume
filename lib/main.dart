import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('PATHLUME_DATA FIREBASE_INITIALIZED_SUCCESS');
  } catch (e) {
    developer.log('PATHLUME_DATA FIREBASE_INITIALIZATION_ERROR error=$e');
  }
  runApp(const PathlumeApp());
}
