// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// The [SharedPreferences] key to access the alarm fire count.
const String countKey = 'count';

/// The name associated with the UI isolate's [SendPort].
const String isolateName = 'isolate';

/// A port used to communicate from a background isolate to the UI isolate.
ReceivePort port = ReceivePort();

/// Global [SharedPreferences] object.
SharedPreferences? prefs;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the UI isolate's SendPort to allow for communication from the
  // background isolate.
  IsolateNameServer.registerPortWithName(
    port.sendPort,
    isolateName,
  );
  prefs = await SharedPreferences.getInstance();
  if (!prefs!.containsKey(countKey)) {
    await prefs!.setInt(countKey, 0);
  }

  runApp(const AlarmManagerExampleApp());
}

/// Example app for Espresso plugin.
class AlarmManagerExampleApp extends StatelessWidget {
  const AlarmManagerExampleApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0x9f4376f8),
      ),
      home: const _AlarmHomePage(),
    );
  }
}

class _AlarmHomePage extends StatefulWidget {
  const _AlarmHomePage({Key? key}) : super(key: key);

  @override
  _AlarmHomePageState createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<_AlarmHomePage> {
  int _counter = 0;
  DateTime _dateTimeReturned = DateTime.now();

  @override
  void initState() {
    super.initState();
    AndroidAlarmManager.initialize();

    // Register for events from the background isolate. These messages will
    // always coincide with an alarm firing.
    port.listen((_) async => await _incrementCounter());
  }

  Future<void> _incrementCounter() async {
    developer.log('Increment counter!');
    // Ensure we've loaded the updated count from the background isolate.
    await prefs?.reload();

    setState(() {
      _counter++;
    });
  }

  // The background
  static SendPort? uiSendPort;

  // The callback for our alarm
  @pragma('vm:entry-point')
  static Future<void> callback(int alarmID) async {
    developer.log('Alarm fired!');
    // Get the previous cached count and increment it.
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);

    setNotification(alarmID);

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium;
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    AndroidInitializationSettings androidInitializationSettings = const AndroidInitializationSettings('@mipmap/ic_launcher');
    InitializationSettings initializationSettings = InitializationSettings(android: androidInitializationSettings);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android alarm manager plus example'),
        elevation: 4,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Alarm fired $_counter times',
              style: textStyle,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Total alarms fired: ',
                  style: textStyle,
                ),
                Text(
                  prefs?.getInt(countKey).toString() ?? '',
                  key: const ValueKey('BackgroundCountText'),
                  style: textStyle,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const ValueKey('RegisterTime'),
              onPressed: () async {
                _dateTimeReturned = await showDateTimePicker(context: context);

              },
              child: const Text(
                'Set Time',
              ),
            ),
            ElevatedButton(
              key: const ValueKey('RegisterOneShotAlarm'),
              onPressed: () async {
                /*
                await AndroidAlarmManager.oneShot(
                  const Duration(seconds: 5),
                  // Ensure we have a unique alarm ID.
                  Random().nextInt(pow(2, 31) as int),
                  callback,
                  exact: true,
                  wakeup: true,
                );*/

                await AndroidAlarmManager.oneShotAt(
                  _dateTimeReturned,
                  // Ensure we have a unique alarm ID.
                  Random().nextInt(pow(2, 31) as int),
                  callback,
                  exact: true,
                  wakeup: true,
                );


              },
              child: const Text(
                'Schedule Notification',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void setNotification(int alarmID) async {
  print('notification set');

  //Read some more stuff from sharedpreference and/or firebase. Use that information for the notification text.


    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails('your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        1, alarmID.toString(), 'plain body', notificationDetails,
        payload: 'item x');

}

Future<DateTime> showDateTimePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  initialDate ??= DateTime.now();
  firstDate ??= initialDate.subtract(const Duration(days: 365 * 100));
  lastDate ??= firstDate.add(const Duration(days: 365 * 200));

  final DateTime? selectedDate = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  if (selectedDate == null) return DateTime.now();

  if (!context.mounted) return selectedDate;

  final TimeOfDay? selectedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(selectedDate),
  );

  return selectedTime == null
      ? selectedDate
      : DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedTime.hour,
    selectedTime.minute,
  );
}
