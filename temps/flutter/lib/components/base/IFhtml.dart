part of '../ui.dart';

Widget baseHTML(Config config, slot) {
  var style = config.style;

  double fontSize = style['fontSize'] ?? 20.0;
  double lineHeight = style['lineHeight'] ?? 22.0;

  TextAttr attr = TextAttr(style);

  var htmlData = GET(config, 'html') ?? '';

  Widget tree = Html(
    data: htmlData,
    style: {
      "body": Style(
        margin: EdgeInsets.all(0),
        padding: EdgeInsets.all(0),
        color: style['color'] ?? Colors.black, 
        fontFamily: attr.fontFamily,
        fontSize: FontSize(fontSize),
        fontWeight: attr.fontWeight,
        textDecoration: attr.textDecoration,
        fontStyle: attr.fontStyle,
        lineHeight: LineHeight(calcLineHeight(lineHeight, fontSize)),
        letterSpacing: attr.letterSpacing,
        textShadow: attr.textShadow
      ), 
      "p": Style(
        margin: EdgeInsets.all(0),
        padding: EdgeInsets.all(0),
        textDecoration: attr.textDecoration,
        fontStyle: attr.fontStyle,
        textAlign: attr.textAlign,
      ),
      "a": Style(
        textDecoration: TextDecoration.none //统一为none
      ),
      "u": Style(
        textDecoration: attr.textDecoration,
      )
    },
   onLinkTap: (url, _, __, ___) async {
     print("Opening $url...");

     await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
   },
  );

  return componentWrap(config, tree);
}
