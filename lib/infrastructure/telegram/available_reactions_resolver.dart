import 'package:flutter/foundation.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

/// Default number of reactions per row requested from TDLib.
const int defaultReactionRowSize = 8;

/// Outcome of querying the reactions available for a specific message.
sealed class AvailableReactionsResult {
  const AvailableReactionsResult();
}

/// One or more free standard emoji reactions can be sent on the message.
final class AvailableReactionsAllowed extends AvailableReactionsResult {
  final List<String> emojis;

  const AvailableReactionsAllowed(this.emojis);
}

/// Reactions are enabled on the message, but every allowed reaction requires
/// Telegram Premium, a custom emoji, or paid Stars.
final class AvailableReactionsCustomOnly extends AvailableReactionsResult {
  const AvailableReactionsCustomOnly();
}

/// Reactions are genuinely disabled on this message/chat.
final class AvailableReactionsOff extends AvailableReactionsResult {
  const AvailableReactionsOff();
}

/// The TDLib lookup failed or timed out.
final class AvailableReactionsFailed extends AvailableReactionsResult {
  const AvailableReactionsFailed();
}

/// Classifies TDLib's [td.AvailableReactions] response into one of the
/// distinct states the UI reports.
AvailableReactionsResult classifyAvailableReactions(td.AvailableReactions res) {
  final emojis = <String>[];
  var hasAnyReaction = false;

  for (final group in [
    res.topReactions,
    res.recentReactions,
    res.popularReactions,
  ]) {
    for (final reaction in group) {
      hasAnyReaction = true;
      if (reaction.needsPremium) continue;
      final type = reaction.type;
      if (type is! td.ReactionTypeEmoji) continue;
      if (!emojis.contains(type.emoji)) {
        emojis.add(type.emoji);
      }
    }
  }

  if (emojis.isNotEmpty) {
    return AvailableReactionsAllowed(List.unmodifiable(emojis));
  }
  if (hasAnyReaction) {
    return const AvailableReactionsCustomOnly();
  }
  return const AvailableReactionsOff();
}

/// Queries TDLib for the reactions available on [chatId]/[messageId], shared by
/// both the Feed and Messages screens.
///
/// For supergroups/channels in the feed whose `SupergroupFullInfo` has not yet
/// been fetched in this session, TDLib's local cache initially holds an empty
/// reaction list; this hydrates `GetSupergroupFullInfo` once on demand and
/// re-queries `GetMessageAvailableReactions`.
Future<AvailableReactionsResult> resolveMessageAvailableReactions(
  TdlibService tdlib, {
  required int chatId,
  required int messageId,
  int rowSize = defaultReactionRowSize,
  Set<int>? hydratedSupergroups,
}) async {
  try {
    final res = await tdlib.sendRequest(
      td.GetMessageAvailableReactions(
        chatId: chatId,
        messageId: messageId,
        rowSize: rowSize,
      ),
    );
    if (res is! td.AvailableReactions) {
      return const AvailableReactionsFailed();
    }

    final initial = classifyAvailableReactions(res);
    if (initial is! AvailableReactionsOff) {
      return initial;
    }

    // In the feed, a channel's allowed reactions live in `SupergroupFullInfo`,
    // which `LoadChats` does not fetch. Hydrate it once on demand when empty.
    try {
      final chatObj = await tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (chatObj is td.Chat) {
        final type = chatObj.type;
        if (type is td.ChatTypeSupergroup) {
          final shouldHydrate =
              hydratedSupergroups == null ||
              hydratedSupergroups.add(type.supergroupId);
          if (shouldHydrate) {
            await tdlib.sendRequest(
              td.GetSupergroupFullInfo(supergroupId: type.supergroupId),
            );
            final retryRes = await tdlib.sendRequest(
              td.GetMessageAvailableReactions(
                chatId: chatId,
                messageId: messageId,
                rowSize: rowSize,
              ),
            );
            if (retryRes is td.AvailableReactions) {
              return classifyAvailableReactions(retryRes);
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[Reactions] Supergroup hydration for $chatId/$messageId failed: $e',
      );
    }

    return initial;
  } catch (e) {
    debugPrint('[Reactions] Lookup for $chatId/$messageId failed: $e');
    return const AvailableReactionsFailed();
  }
}
