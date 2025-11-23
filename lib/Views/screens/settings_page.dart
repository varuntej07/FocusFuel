import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final bool _calendarConnected = false;
  final bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCalendarSection(),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Google Calendar'),
        subtitle: Text(_calendarConnected
            ? 'Connected - Meeting notifications enabled'
            : 'Connect to get meeting notifications'),
        trailing: _isConnecting
            ? const CircularProgressIndicator()
            : Switch(
          value: _calendarConnected,
          onChanged: (value) => _connectCalendar(),
        ),
      ),
    );
  }

  Future<void> _connectCalendar() async {}
}