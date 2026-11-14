import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/utils/borrower_assistant_conversation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps conversations until 24 hours from their start time', () async {
    SharedPreferences.setMockInitialValues({});
    final startedAt = DateTime(2026, 11, 14, 8);
    final conversation = BorrowerAssistantConversation(
      startedAt: startedAt,
      messages: const [
        BorrowerAssistantConversationMessage(
          text: 'Anong mga gamit ang available?',
          fromUser: true,
        ),
        BorrowerAssistantConversationMessage(
          text: 'Available ang projector.',
          fromUser: false,
        ),
      ],
    );
    await BorrowerAssistantConversationStore.save('user-1', conversation);

    final restored = await BorrowerAssistantConversationStore.load(
      'user-1',
      now: startedAt.add(const Duration(hours: 23, minutes: 59)),
    );
    expect(restored?.messages.map((message) => message.text), [
      'Anong mga gamit ang available?',
      'Available ang projector.',
    ]);
    expect(
      await BorrowerAssistantConversationStore.load(
        'user-2',
        now: startedAt.add(const Duration(hours: 1)),
      ),
      isNull,
    );

    final expired = await BorrowerAssistantConversationStore.load(
      'user-1',
      now: startedAt.add(const Duration(hours: 24)),
    );
    expect(expired, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'borrower_assistant_conversation_user-1',
      ),
      isNull,
    );
  });
}
