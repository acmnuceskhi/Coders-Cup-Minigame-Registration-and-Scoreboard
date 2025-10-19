import 'package:coders_cup_minigame_frontend/models/form_field.dart';

class Game {
  String id;
  String name;
  String? description;
  String? instructions;
  int? limit; // optional
  bool codeBased = false;
  List<FormField> formFields = [];
  bool allowNonNuIds = false;
  String? backgroundImage;
  String? bottomLeftImage;
  String? bottomRightImage;
  String? primaryColor; // hex string like #FFAABBCC
  bool scoreboardDisabled = false;

  Game({
    required this.id,
    required this.name,
    this.description,
    this.instructions,
    this.limit,
    this.codeBased = false,
    this.allowNonNuIds = false,
    this.backgroundImage,
    this.bottomLeftImage,
    this.bottomRightImage,
    this.primaryColor,
    this.scoreboardDisabled = false,
  });
}
