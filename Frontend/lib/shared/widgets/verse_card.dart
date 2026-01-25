import 'dart:async';
import 'package:flutter/material.dart';

class VerseCard extends StatefulWidget {
  final String verseId;
  final String verseContent;
  final String note;
  final int likesCount;
  final int commentCount;
  final String? username;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final bool isSaved;
  final bool isPublished;
  final ValueChanged<String> onSaveNote;
  final ValueChanged<String>? onPublish;
  final VoidCallback? onUnpublish;
  final VoidCallback? onDelete;

  VerseCard(
      {required this.verseId,
      required this.note,
      required this.verseContent,
      required this.likesCount,
      required this.commentCount,
      required this.onLike,
      required this.onComment,
      required this.isSaved,
      required this.isPublished,
      required this.onSaveNote,
      this.username,
      this.onPublish,
      this.onUnpublish,
      this.onDelete});

  @override
  _VerseCardState createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  bool _isExpanded = false;
  TextEditingController _noteController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    _noteController.text = widget.note;
    super.initState();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.light
        ? theme.cardColor.withOpacity(0.9)
        : theme.cardColor;

    return GestureDetector(
      onTap: widget.isSaved ? _toggleExpand : widget.onComment,
      behavior: HitTestBehavior.translucent,
      child: Card(
        margin: const EdgeInsets.all(8.0),
        color: backgroundColor,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.verseId),
              subtitle: Text(
                widget.verseContent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: widget.isSaved
                  ? IconButton(
                      icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: _toggleExpand,
                    )
                  : null,
            ),
            if (!_isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          constraints: const BoxConstraints(
                            maxWidth: 400.0,
                          ),
                          child: Text(
                            widget.note,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            if (_isExpanded && widget.isSaved)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'Add a note here!',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            widget.onSaveNote(_noteController.text);
                          },
                          child: const Text('Save Note'),
                        ),
                        const SizedBox(width: 12.0),
                        if (widget.isPublished && widget.onUnpublish != null)
                          ElevatedButton(
                            onPressed: widget.onUnpublish,
                            child: const Text('Unpublish'),
                          )
                        else if (!widget.isPublished &&
                            widget.onPublish != null)
                          ElevatedButton(
                            onPressed: () {
                              widget.onPublish!(_noteController.text);
                            },
                            child: const Text('Publish'),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.only(right: 8.0, bottom: 8.0, left: 18.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (!widget.isSaved) Text(widget.likesCount.toString()),
                if (!widget.isSaved)
                  IconButton(
                    icon: const Icon(Icons.thumb_up),
                    onPressed: widget.onLike,
                  ),
                Text(widget.commentCount.toString()),
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: widget.onComment,
                ),
                if (widget.isSaved && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete',
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
