import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import '../Models/debate_stream_event.dart';

/// Service for streaming debates via SSE (Server-Sent Events)
class DebateStreamService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud Functions endpoint URL
  static const String _functionBaseUrl = 'https://us-central1-focusfuel-bbd48.cloudfunctions.net';

  /// Start a debate stream; returns a stream of DebateStreamEvent objects
  Stream<DebateStreamEvent> startDebateStream({
    required String dilemma,
    required String customAgentPresetId,
    required String debateId,
  }) async* {               // asynchronous generator; uses yield to emit values into returned stream without terminating
    final user = _auth.currentUser;
    if (user == null) {
      yield ErrorEvent(message: 'User not authenticated');
      return;
    }

    String? idToken;
    try {
      idToken = await user.getIdToken();
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to get ID token for debate stream'],
      );
      yield ErrorEvent(message: 'Authentication failed');
      return;
    }

    if (idToken == null) {
      yield ErrorEvent(message: 'Failed to get authentication token');
      return;
    }

    final url = Uri.parse('$_functionBaseUrl/debateStream');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Authorization': 'Bearer $idToken',
    };

    final body = jsonEncode({
      'dilemma': dilemma,
      'customAgentPresetId': customAgentPresetId,
      'debateId': debateId,
    });

    http.Client? client;          // client to send requests
    http.StreamedResponse? response;

    try {
      client = http.Client();         //creates an IOClient which wraps dart:io's HttpClient
      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      // Opens a TCP socket connection to 'url', sends request and returns a StreamedResponse immediately
      // this type of response is used when the response body will be received as a stream of data over time.
      response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        String errorMessage = 'Server error: ${response.statusCode}';

        try {
          final errorJson = jsonDecode(errorBody);
          errorMessage = errorJson['error'] ?? errorMessage;
        } catch (e) {
          // If error body is HTML (server error page), show friendly message
          if (errorBody.contains('<html') || errorBody.contains('<!DOCTYPE')) {
            if (response.statusCode == 404) {
              errorMessage = 'Debate service not available. Please try again later.';
            } else if (response.statusCode == 500) {
              errorMessage = 'Server error. Please try again later.';
            } else if (response.statusCode == 429) {
              errorMessage = 'Daily debate limit reached. Upgrade to Premium for more debates!';
            } else {
              errorMessage = 'Service temporarily unavailable (${response.statusCode})';
            }
          } else if (errorBody.isNotEmpty && errorBody.length < 200) {
            // Only use raw error if it's short and not HTML
            errorMessage = errorBody;
          }
        }

        FirebaseCrashlytics.instance.log('Debate stream error: $errorMessage (status: ${response.statusCode})');
        yield ErrorEvent(message: errorMessage);
        return;
      }

      // If request is successful; parse Server-Sent Events (SSE) Stream
      // first utf8.decoder decodes raw byte stream from responses and then splits the stream of strings into individual lines.
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? currentEvent;
      String? currentData;

      // then iterates through each line using an 'await for' loop
      await for (final line in stream) {
        if (line.isEmpty) {         // Empty line indicates end of event
          if (currentEvent != null && currentData != null) {
            final event = _parseEvent(currentEvent, currentData);
            if (event != null) {
              yield event;

              // If we get a done or error event, close the stream
              if (event is DoneEvent || event is ErrorEvent) {
                break;
              }
            }
          }
          currentEvent = null;
          currentData = null;
        } else if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          currentData = line.substring(5).trim();
        }
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Error in debate stream connection'],
      );
      yield ErrorEvent(message: 'Connection error: ${error.toString()}');
    } finally {
      client?.close();
    }
  }

  /// Parse SSE event into DebateStreamEvent
  DebateStreamEvent? _parseEvent(String eventType, String dataString) {
    try {
      final data = jsonDecode(dataString) as Map<String, dynamic>;

      switch (eventType) {
        case 'connected':
          return ConnectedEvent();

        case 'turn_start':
          return TurnStartEvent.fromJson(data);

        case 'token':
          return TokenEvent.fromJson(data);

        case 'turn_end':
          return TurnEndEvent.fromJson(data);

        case 'audio_ready':
          return AudioReadyEvent.fromJson(data);

        case 'summary_start':
          return SummaryStartEvent.fromJson(data);

        case 'debate_complete':
          return DebateCompleteEvent.fromJson(data);

        case 'error':
          return ErrorEvent.fromJson(data);

        case 'done':
          return DoneEvent();

        default:
          FirebaseCrashlytics.instance.log('Unknown SSE event type: $eventType');
          return null;
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to parse SSE event: $eventType'],
      );
      return ErrorEvent(message: 'Failed to parse event');
    }
  }
}
