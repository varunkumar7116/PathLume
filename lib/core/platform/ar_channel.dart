import 'package:flutter/services.dart';

class ARChannel {
  static const MethodChannel methodChannel =
      MethodChannel('com.pathlume.app/ar_channel');

  static const EventChannel trackingEventChannel =
      EventChannel('com.pathlume.app/ar_events');
}
