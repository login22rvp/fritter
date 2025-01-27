import 'dart:developer';
import 'dart:math' as math;

import 'package:auto_direction/auto_direction.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:fritter/client.dart';
import 'package:fritter/home_model.dart';
import 'package:fritter/tweet/_card.dart';
import 'package:fritter/tweet/_content.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import 'profile.dart';

class TweetMedia extends StatefulWidget {
  final List<Media> media;

  const TweetMedia({Key? key, required this.media}) : super(key: key);

  @override
  _TweetMediaState createState() => _TweetMediaState();
}

class _TweetMediaState extends State<TweetMedia> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    var largestAspectRatio = widget.media
      .map((e) => ((e.sizes!.large!.w) ?? 1) / ((e.sizes!.large!.h) ?? 1))
      .reduce(math.max);

    return Container(
      margin: EdgeInsets.only(top: 8, left: 16, right: 16),
      child: AspectRatio(
        aspectRatio: largestAspectRatio,
        child: PageView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemCount: widget.media.length,
          itemBuilder: (context, index) {
            Widget media;

            var item = widget.media[index];
            if (item.type == 'animated_gif') {
              media = TweetVideo(media: item, loop: true);
            } else if (item.type == 'video') {
              media = TweetVideo(media: item, loop: false);
            } else if (item.type == 'photo') {
              media = ExtendedImage.network(item.mediaUrlHttps!, cache: true);
            } else {
              media = Text('Unknown');
            }

            if (widget.media.length == 1) {
              return media;
            }

            return Stack(
              children: [
                Center(child: media),
                Positioned(
                  right: 0,
                  child: Container(
                    alignment: Alignment.topRight,
                    color: Colors.black38,
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(8),
                    child: Text('${++index} / ${widget.media.length}'),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}


class TweetVideo extends StatefulWidget {
  final bool loop;
  final Media media;

  const TweetVideo({Key? key, required this.loop, required this.media}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TweetVideoState();
}

class _TweetVideoState extends State<TweetVideo> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.network(widget.media.videoInfo!.variants![0].url!);
    _controller.setLooping(widget.loop);
    _controller.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });

    _controller.addListener(() {
      setState(() {});
    });
  }

  Widget _createControls() {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: Duration(milliseconds: 50),
          reverseDuration: Duration(milliseconds: 200),
          child: _controller.value.isPlaying
              ? SizedBox.shrink()
              : Container(
            color: Colors.black26,
            child: Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 100.0,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          },
        ),
      ],
    );

  }

  @override
  Widget build(BuildContext context) {
    double aspectRatio = widget.media.videoInfo?.aspectRatio == null
      ?  _controller.value.aspectRatio
      : widget.media.videoInfo!.aspectRatio![0] / widget.media.videoInfo!.aspectRatio![1];

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_controller),
            _createControls(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

class TweetTile extends StatelessWidget {
  final bool clickable;
  final String? currentUsername;
  final TweetWithCard? tweet;

  const TweetTile({Key? key, required this.clickable, this.currentUsername, this.tweet}) : super(key: key);

  _createFooterIconButton(IconData icon, [Color? color, Function()? onPressed]) {
    return InkWell(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        child: Icon(icon, size: 14, color: color),
      ),
      onTap: onPressed,
    );
  }

  _createFooterTextButton(IconData icon, String label, [Color? color, Function()? onPressed]) {
    return TextButton.icon(
      icon: Icon(icon, size: 14, color: color),
      onPressed: onPressed,
      label: Text(label, style: TextStyle(
        color: color,
        fontSize: 12.5
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (this.tweet == null) {
      return Container();
    }

    var numberFormat = NumberFormat.compact();
    var actionColour = Theme.of(context).disabledColor;

    TweetWithCard tweet = this.tweet!.retweetedStatusWithCard == null
      ? this.tweet!
      : this.tweet!.retweetedStatusWithCard!;

    Widget media = Container();
    if (tweet.extendedEntities?.media != null && tweet.extendedEntities!.media!.isNotEmpty) {
      media = TweetMedia(media: tweet.extendedEntities!.media!);
    }

    Widget retweetBanner = Container();
    if (this.tweet!.retweetedStatusWithCard != null) {
      retweetBanner = ColoredBox(
          color: Theme.of(context).secondaryHeaderColor,
          child: Center(
            child: Padding(
                padding: EdgeInsets.all(8),
                child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                          color: Theme.of(context).primaryColorDark
                      ),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.repeat, size: 14, color: Theme.of(context).primaryColorDark),
                        ),
                      ],
                    )
                )
            ),
          )
      );
    }

    var tweetText = tweet.fullText == null
        ? tweet.text
        : tweet.fullText;

    if (tweetText == null) {
      var message = 'The tweet did not contain any text. This is unexpected';

      log(message);

      return Container(child: Text(
          'The tweet did not contain any text. This is unexpected'
      ));
    }

    var quotedTweet = Container();
    if (tweet.isQuoteStatus ?? false) {
      Widget quotedTweetTile;

      if (tweet.quotedStatusWithCard != null) {
        quotedTweetTile = TweetTile(
          clickable: true,
          tweet: tweet.quotedStatusWithCard,
          currentUsername: tweet.user?.screenName,
        );
      } else {
        quotedTweetTile = Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text('This tweet is unavailable', style: TextStyle(
              color: Theme.of(context).hintColor
          )),
        );
      }

      quotedTweet = Container(
        decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).primaryColor),
            borderRadius: BorderRadius.circular(8)
        ),
        margin: EdgeInsets.all(8),
        child: Container(
          child: quotedTweetTile,
        ),
      );
    }

    return Consumer<HomeModel>(builder: (context, model, child) => Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              child: retweetBanner,
            ),
            Expanded(child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      onTap: () {
                        // If the tweet is by the currently-viewed profile, don't allow clicks as it doesn't make sense
                        if (currentUsername != null && tweet.user!.screenName!.endsWith(currentUsername!)) {
                          return null;
                        }

                        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(id: tweet.user!.idStr, username: tweet.user!.screenName!)));
                      },
                      title: Text(tweet.user!.name!,
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(tweet.user!.screenName!),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: ExtendedNetworkImageProvider(tweet.user!.profileImageUrlHttps!.replaceAll('normal', '200x200'), cache: true),
                      ),
                      trailing: Text(timeago.format(tweet.createdAt!),
                          style: Theme.of(context).textTheme.caption),
                    ),
                    Container(
                      // Fill the width so both RTL and LTR text are displayed correctly
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: AutoDirection(
                        text: tweetText,
                        child: TweetContent(tweet: tweet),
                      ),
                    ),
                    media,
                    quotedTweet,
                    TweetCard(tweet: tweet, card: tweet.card),
                  ],
                ),
                ButtonBar(
                  buttonTextTheme: ButtonTextTheme.accent,
                  buttonPadding: EdgeInsets.symmetric(horizontal: 0),
                  children: [
                    if (tweet.replyCount != null)
                      _createFooterTextButton(Icons.comment, numberFormat.format(tweet.replyCount)),
                    if (tweet.retweetCount != null)
                      _createFooterTextButton(Icons.repeat, numberFormat.format(tweet.retweetCount)),
                    if (tweet.quoteCount != null)
                      _createFooterTextButton(Icons.message, numberFormat.format(tweet.quoteCount)),
                    if (tweet.favoriteCount != null)
                      _createFooterTextButton(Icons.favorite, numberFormat.format(tweet.favoriteCount)),
                    FutureBuilder<bool>(
                      future: model.isTweetSaved(tweet.idStr!),
                      builder: (context, snapshot) {
                        var saved = snapshot.data;
                        if (saved == null) {
                          return _createFooterIconButton(Icons.bookmark_outline);
                        }

                        if (saved) {
                          return _createFooterIconButton(Icons.bookmark, actionColour, () async {
                            await model.deleteSavedTweet(tweet.idStr!);
                          });
                        } else {
                          return _createFooterIconButton(Icons.bookmark_outline, actionColour, () async {
                            await model.saveTweet(tweet.idStr!, tweet.toJson());
                          });
                        }},
                    ),
                    _createFooterIconButton(Icons.share, actionColour, () async {
                      var createShareDialogItem = (String text, String shareContent) => SimpleDialogOption(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: Text(text, style: TextStyle(
                              fontSize: 16
                          )),
                        ),
                        onPressed: () => Share.share(shareContent),
                      );

                      showDialog(context: context, builder: (context) {
                        return SimpleDialog(
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          children: [
                            createShareDialogItem('Share tweet content', tweetText),
                            createShareDialogItem('Share tweet link', 'https://twitter.com/${tweet.user!.screenName}/status/${tweet.idStr}'),
                          ],
                        );
                      });
                    })
                  ],
                )
              ],
            ))
          ],
        ),
      ),
    ));
  }
}
