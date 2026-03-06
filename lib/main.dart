import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/app.dart';
import 'engine/progression/progression_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await ProgressionManager.instance.init();
  runApp(const ProviderScope(child: BlackjackTrainerApp()));
}
