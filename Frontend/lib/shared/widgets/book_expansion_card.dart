import 'package:flutter/material.dart';

class BookExpansionCard extends StatefulWidget {
  final Widget title;
  final List<Widget> children;
  final EdgeInsetsGeometry tilePadding;
  final Color backgroundColor;

  const BookExpansionCard({
    required this.title,
    required this.children,
    this.tilePadding = const EdgeInsets.all(0),
    required this.backgroundColor,
    super.key,
  });

  @override
  BookExpansionCardState createState() => BookExpansionCardState();
}

class BookExpansionCardState extends State<BookExpansionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Column(
          children: [
            Container(
              padding: widget.tilePadding,
              child: widget.title,
            ),
            if (_isExpanded)
              Container(
                color: widget.backgroundColor,
                child: Column(
                  children: widget.children,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
