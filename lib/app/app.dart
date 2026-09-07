import 'package:flutter/material.dart';
import '../services/repositories/building_repository.dart';
import 'app_theme.dart';
import '../features/home/presentation/home_screen.dart';

class PathlumeApp extends StatelessWidget {
  final BuildingRepository? repository;

  const PathlumeApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PATHLUME AR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(repository: repository),
    );
  }
}
