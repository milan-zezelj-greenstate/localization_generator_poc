import 'dart:convert';
import 'dart:io';

class RegexMatch {
  int start;
  int end;
  String value;

  @override
  String toString() {
    return this.value;
  }

  RegexMatch({required this.start, required this.end, required this.value});
}

void main() async {
  final filePath = "assets/example.json";

  localize(filePath: filePath);
}

void localize({required String filePath}) async {
  final jsonFile = await File(filePath).readAsString();
  final json = jsonDecode(jsonFile);

  final translations = json["translations"];

  for (final translation in translations) {
    jsonToArb(translation);
  }
}

void jsonToArb(Map<String, dynamic> json) async {
  final language = json["language"];
  final fileName = "app_$language.arb";

  final file = File("assets/localization/$fileName");
  await file.create(recursive: true);

  final translations = json["values"];

  Map<String, dynamic> result = {"@@locale": language};

  for (final translation in translations) {
    result.addAll(convertTranslation(translation));
  }

  await file.writeAsString(jsonEncode(result));
}

Map<String, dynamic> convertTranslation(Map<String, dynamic> translation) {
  Map<String, dynamic> result = {};
  final placeholderRegExp = RegExp("(?<!'){([^}]*)}");

  final placeholders = placeholderRegExp
      .allMatches(translation["value"])
      .map((e) => RegexMatch(start: e.start, end: e.end, value: e.group(1)!))
      .toList();

  String value = translation["value"];

  if (placeholders.isNotEmpty) {
    for (final placeholder in placeholders) {
      final variable = translation["placeholders"][placeholder.value];

      if (variable["mode"] == "plural") {
        String firstPart = value.substring(0, placeholder.end);
        String secondPart = value.substring(placeholder.end, value.length);
        firstPart += "{${placeholder.value}, plural, ";
        for (final valueKey in variable["values"].keys) {
          String variableValue = variable["values"][valueKey];

          final temp =
              "${valueKey != "other" ? "=" : ""}$valueKey{$variableValue}";

          firstPart += temp;
        }

        value = firstPart + "}" + secondPart;
      }

      if (variable["mode"] == "select") {
        String firstPart = value.substring(0, placeholder.start);
        String secondPart = value.substring(placeholder.end, value.length);
        firstPart += "{${placeholder.value}, select, ";
        for (final valueKey in variable["values"].keys) {
          String variableValue = variable["values"][valueKey];

          final temp = "$valueKey{$variableValue}";

          firstPart += temp;
        }

        value = firstPart + secondPart + "}";
      }
    }
  }

  result[translation["key"]] = value;

  if (translation["description"] != null ||
      translation["placeholders"] != null) {
    final variableName = "@${translation["key"]}";
    result[variableName] = {};

    if (translation["description"] != null) {
      result[variableName].addAll({
        "description": translation["description"],
      });
    }
    if (translation["placeholders"] != null) {
      Map<String, dynamic> plc = translation["placeholders"];

      plc.map((key, value) {
        value.remove("mode");
        value.remove("values");
        return MapEntry(key, value);
      });

      result[variableName].addAll({
        "placeholders": plc,
      });
    }
  }

  return result;
}
