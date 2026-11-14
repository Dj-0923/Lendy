import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/equipment_model.dart';
import '../providers/auth_provider.dart';

class BorrowerAssistantApiException implements Exception {
  const BorrowerAssistantApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BorrowerAssistantItem {
  const BorrowerAssistantItem({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.tag,
    required this.statusLabel,
    required this.status,
  });

  factory BorrowerAssistantItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final statusLabel = json['status'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        statusLabel is! String) {
      throw const FormatException('The assistant returned an invalid item.');
    }
    final status = switch (statusLabel) {
      'Borrowed' => EquipmentStatus.borrowed,
      'Return Pending' => EquipmentStatus.reserved,
      'In Maintenance' => EquipmentStatus.maintenance,
      'Available' => EquipmentStatus.available,
      _ => throw const FormatException(
        'The assistant returned an invalid item status.',
      ),
    };
    return BorrowerAssistantItem(
      id: id,
      name: name,
      category: json['category'] is String ? json['category'] as String : '',
      location: json['location'] is String ? json['location'] as String : '',
      tag: json['tag'] is String ? json['tag'] as String : '',
      statusLabel: statusLabel,
      status: status,
    );
  }

  final String id;
  final String name;
  final String category;
  final String location;
  final String tag;
  final String statusLabel;
  final EquipmentStatus status;

  EquipmentModel toEquipmentModel() => EquipmentModel.fromFirestore(
    documentId: id,
    data: {
      'name': name,
      'category': category,
      'location': location,
      'tag': tag,
    },
    status: status,
  );
}

class BorrowerAssistantReply {
  const BorrowerAssistantReply({required this.answer, required this.items});

  final String answer;
  final List<BorrowerAssistantItem> items;
}

class BorrowerAssistantService {
  BorrowerAssistantService({
    http.Client? client,
    Future<String?> Function()? getIdToken,
    this.apiUrl = approvalApiUrl,
  }) : _client = client,
       _getIdToken = getIdToken;

  final http.Client? _client;
  final Future<String?> Function()? _getIdToken;
  final String apiUrl;

  Future<BorrowerAssistantReply> ask(String question) async {
    final token = _getIdToken == null
        ? await FirebaseAuth.instance.currentUser?.getIdToken()
        : await _getIdToken();
    if (token == null || token.isEmpty) {
      throw const BorrowerAssistantApiException(
        'Please sign in again to use the assistant.',
      );
    }

    final client = _client ?? http.Client();
    late final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('$apiUrl/borrower-assistant'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(seconds: 55));
    } on TimeoutException {
      rethrow;
    } on http.ClientException {
      rethrow;
    } finally {
      if (_client == null) client.close();
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The assistant returned an invalid response.');
    }
    if (response.statusCode != 200) {
      final message = decoded['error'];
      throw BorrowerAssistantApiException(
        message is String ? message : 'Could not get an assistant response.',
      );
    }
    final answer = decoded['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const FormatException('The assistant returned an invalid answer.');
    }
    final rawItems = decoded['items'];
    if (rawItems is! List) {
      throw const FormatException('The assistant returned invalid item data.');
    }
    final items = <BorrowerAssistantItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('The assistant returned an invalid item.');
      }
      items.add(BorrowerAssistantItem.fromJson(rawItem));
    }
    return BorrowerAssistantReply(answer: answer, items: items);
  }
}
