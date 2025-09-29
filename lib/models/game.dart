import 'package:coders_cup_minigame_frontend/models/form_field.dart';

class Game {
  String id;
  String name;
  int? limit; // optional
  bool codeBased = false;
  List<FormField> formFields = [];
  String? backgroundImage;
  String? bottomLeftImage;
  String? bottomRightImage;
  String? primaryColor; // hex string like #FFAABBCC

  Game({
    required this.id,
    required this.name,
    this.limit,
    this.codeBased = false,
    this.backgroundImage,
    this.bottomLeftImage,
    this.bottomRightImage,
    this.primaryColor,
  });
}
