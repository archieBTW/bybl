// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setBodyBackground(String hex) {
  html.document.body!.style.backgroundColor = hex;
}
