import 'package:audioplayers/audioplayers.dart';

/// Short UI sounds for the main menu.
class MainPageSound {
  MainPageSound._();

  static final _buttonClick =
      AssetSource('sounds/main-page/button-click.wav');

  static final AudioPlayer _clickPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static void playButtonClick() {
    _clickPlayer.stop();
    _clickPlayer.play(_buttonClick);
  }
}
