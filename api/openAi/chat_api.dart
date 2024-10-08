import 'package:dart_openai/dart_openai.dart';
import 'package:uuid/uuid.dart';

import '../../domain/api/chat/i_chat_api.dart';
import '../../domain/core/enums.dart';
import '../../domain/models/message/message.dart';
import '../../domain/models/stream_message/stream_message.dart';

const MAX_TOKEN_CONTEXT_LIMIT = 4096;

class OpenAIChatApi implements IChatApi {
  OpenAIChatApi({required String? apiKey}) {
    if (apiKey != null) {
      OpenAI.apiKey = apiKey;
    }
  }

  @override
  Future<Message> createChatCompletion(
    List<Message> messages,
    String chatId,
    String model,
  ) async {
    if (messages.isEmpty) {
      throw Exception('No messages to convert');
    }

    final openAIMessages = _convertToOpenAIMessages(messages);

    final completionModel = await OpenAI.instance.chat.create(
      model: model,
      messages: openAIMessages,
    );

    final message = _convertToMessage(completionModel.choices.first, chatId);

    return message;
  }

  @override
  Stream<StreamMessage> createChatCompletionStream(
    List<Message> messages,
    double? temperature,
    String model,
  ) {
    final openAIMessages = _convertToOpenAIMessages(messages);

    final stream = OpenAI.instance.chat.createStream(
      model: model,
      messages: openAIMessages,
      temperature: temperature,
    );

    return stream.map(
      (event) => StreamMessage(
        message: _convertStreamMessageToMessage(event),
        finishReason: event.choices[0].finishReason,
      ),
    );
  }

  Message _convertStreamMessageToMessage(
    OpenAIStreamChatCompletionModel completionModel,
  ) {
    if (completionModel is FormatException) {
      return Message(
        id: 'partial',
        chatId: 'partial',
        content: 'Error',
        sentAt: DateTime.now(),
        isUser: false,
        role: EMessageRole.assistant,
      );
    }
    return Message(
      id: 'partial',
      chatId: 'partial',
      content: completionModel.choices.first.delta.content ?? '',
      sentAt: DateTime.now(),
      isUser: completionModel.choices.first.delta.role == 'user',
      role: _openAiRoleToMessageRole(
        OpenAIChatMessageRole.assistant,
      ),
    );
  }

  List<OpenAIChatCompletionChoiceMessageModel> _convertToOpenAIMessages(
    List<Message> allMessages,
  ) {
    // First, trim the messages to fit within the max token count
    final messages =
        _trimMessagesToFitTokenLimit(allMessages, MAX_TOKEN_CONTEXT_LIMIT);

    // Then, convert the trimmed messages to OpenAIChatCompletionChoiceMessageModel objects
    return messages.map((message) {
      final openAiMessage = OpenAIChatCompletionChoiceMessageModel(
        role: _messageRoleToOpenAiRole(message.role),
        content: message.content,
      );

      return openAiMessage;
    }).toList();
  }

  Message _convertToMessage(
    OpenAIChatCompletionChoiceModel openAIChoice,
    String chatId,
  ) {
    return Message(
      id: const Uuid().v4(),
      chatId: chatId,
      content: openAIChoice.message.content,
      sentAt: DateTime.now(),
      isUser: openAIChoice.message.role.toString() == 'user',
      role: _openAiRoleToMessageRole(openAIChoice.message.role),
    );
  }

  OpenAIChatMessageRole _messageRoleToOpenAiRole(EMessageRole role) {
    final roleString = role.toString().split('.').last;
    return OpenAIChatMessageRole.values
        .firstWhere((e) => e.toString().split('.').last == roleString);
  }

  EMessageRole _openAiRoleToMessageRole(OpenAIChatMessageRole role) {
    final roleString = role.toString().split('.').last;
    return EMessageRole.values
        .firstWhere((e) => e.toString().split('.').last == roleString);
  }

  int _estimateTokenCount(String message) {
    final characterCount = message.length;

    // Estimate token count by dividing character count by 4 and rounding to the nearest whole number
    final tokenCount = (characterCount / 4).round();

    return tokenCount;
  }

  List<Message> _trimMessagesToFitTokenLimit(
    List<Message> allMessages,
    int maxTokens,
  ) {
    final limitedMessages = <Message>[];
    var totalTokenCount = 0;

    // The error margin is used to ensure that the total token count does not exceed the max token count
    // The error margin is a percentage of the max token count
    const errorMargin = 0.85;

    // Start from the end of the list, since we want the latest messages
    for (var i = allMessages.length - 1; i >= 0; i--) {
      final messageTokenCount = _estimateTokenCount(allMessages[i].content);

      // Check if adding this message would exceed the max token count
      if (totalTokenCount + messageTokenCount <= maxTokens * errorMargin) {
        limitedMessages.insert(
          0,
          allMessages[i],
        ); // Add the message to the beginning of the list
        totalTokenCount += messageTokenCount; // Increase the total token count
      } else {
        // If adding this message would exceed the max token count, stop the loop
        break;
      }
    }

    // Return the list of messages that fit within the max token count
    return limitedMessages;
  }
}
