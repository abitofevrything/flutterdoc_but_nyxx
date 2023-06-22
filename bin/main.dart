import 'dart:io';

import 'package:flutterdoc_but_nyxx/search.dart';
import 'package:nyxx/nyxx.dart';

void main() async {
  final client = await Nyxx.connectGateway(
    Platform.environment['TOKEN']!,
    GatewayIntents.guildMessages | GatewayIntents.messageContent,
    options: GatewayClientOptions(plugins: [logging, cliIntegration]),
  );

  client.onMessageCreate.listen(handleSearch);
}

void handleSearch(MessageCreateEvent event) async {
  final pattern = RegExp(r'(?<prefix>!|\?|\$|&)\[((?<package>\w+)/)?(?<query>(\w|\.|\[\]| )+)\]');

  for (final match in pattern.allMatches(event.message.content)) {
    final prefix = match.namedGroup('prefix')!;
    final package = match.namedGroup('package') ?? 'flutter';
    final query = match.namedGroup('query')!;

    final notFound = MessageBuilder(embeds: [
      Embed(
        title: 'Not found: $query',
        description: null,
        url: null,
        timestamp: null,
        color: DiscordColor.fromRgb(255, 0, 0),
        footer: null,
        image: null,
        thumbnail: null,
        video: null,
        provider: null,
        author: null,
        fields: null,
      ),
    ]);

    if (['!', '?'].contains(prefix)) {
      final result = await searchDocs(package, query);

      if (result.isEmpty) {
        await event.message.channel.sendMessage(notFound);
        return;
      }

      if (prefix == '!') {
        await event.message.channel.sendMessage(
          MessageBuilder(content: result.first.urlToDocs),
        );
      } else {
        await event.message.channel.sendMessage(MessageBuilder(embeds: [
          Embed(
            title: '$query - Search results',
            description:
                result.take(10).map((e) => '[${e.displayName}](${e.urlToDocs})').join('\n'),
            url: null,
            timestamp: null,
            color: null,
            footer: null,
            image: null,
            thumbnail: null,
            video: null,
            provider: null,
            author: null,
            fields: null,
          ),
        ]));
      }
    } else {
      final result = await searchPackages(query);

      if (result.isEmpty) {
        await event.message.channel.sendMessage(notFound);
        return;
      }

      if (prefix == '\$') {
        await event.message.channel.sendMessage(
          MessageBuilder(content: 'https://pub.dev/packages/${result.first}'),
        );
      } else {
        await event.message.channel.sendMessage(MessageBuilder(embeds: [
          Embed(
            title: '$query - Package search results',
            description:
                result.take(10).map((e) => '[$e](https://pub.dev/paclkages/$e)').join('\n'),
            url: null,
            timestamp: null,
            color: null,
            footer: null,
            image: null,
            thumbnail: null,
            video: null,
            provider: null,
            author: null,
            fields: null,
          ),
        ]));
      }
    }
  }
}
