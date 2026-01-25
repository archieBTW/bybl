import 'dart:convert';
import 'package:TheWord/providers/verse_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';

class CommentsScreen extends StatefulWidget {
  final dynamic verse;

  const CommentsScreen({required this.verse});

  @override
  State<StatefulWidget> createState() => CommentsScreenState();
}

class CommentsScreenState extends State<CommentsScreen> {
  dynamic verse;
  List comments = [];
  bool isLoading = false;
  int likesCount = 0;

  @override
  void initState() {
    verse = widget.verse;
    super.initState();
    fetchComments();
    fetchLikesCount();
  }

  Future<void> fetchComments() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(
          'https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/comments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      if (response.body != null) {
        setState(() {
          comments = json.decode(response.body) ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          comments = [];
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load comments');
    }
  }

  Future<void> fetchLikesCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/likes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      setState(() {
        likesCount = json.decode(response.body)['likes_count'];
      });
    } else {
      throw Exception('Failed to load likes count');
    }
  }

  Future<void> toggleLike() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');

    final response = await http.post(
      Uri.parse(
          'https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/toggle-like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      fetchLikesCount();
    } else {
      throw Exception('Failed to toggle like');
    }
  }

  Future<void> addComment(String content, {int? parentCommentID}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');
    final response = await http.post(
      Uri.parse(
          'https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/comment${parentCommentID != null ? "?parentCommentID=$parentCommentID" : ""}'),
      headers: {'Authorization': 'Bearer $token'},
      body: json.encode({'content': content}),
    );
    if (response.statusCode == 200) {
      await fetchComments();
    } else {
      throw Exception('Failed to add comment');
    }
  }

  Future<void> updateComment(int commentID, String content) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');
    final response = await http.put(
      Uri.parse(
          'https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/comment/$commentID'),
      headers: {'Authorization': 'Bearer $token'},
      body: json.encode({'content': content}),
    );
    if (response.statusCode == 200) {
      await fetchComments();
    } else {
      throw Exception('Failed to update comment');
    }
  }

  Future<void> deleteComment(int commentID) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('token');
    final response = await http.delete(
      Uri.parse(
          'https://api.bybl.dev/api/verse/${verse["UserVerseID"]}/comment/$commentID'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      await fetchComments();
    } else {
      throw Exception('Failed to delete comment');
    }
  }

  void showAddCommentDialog(BuildContext context, {int? parentCommentID}) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration:
              const InputDecoration(hintText: 'Enter your comment here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await addComment(commentController.text,
                  parentCommentID: parentCommentID);
              Provider.of<VerseProvider>(context, listen: false)
                  .fetchPublicVerses(reset: true, silent: true);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void showEditCommentDialog(
      BuildContext context, int commentID, String currentContent) {
    final commentController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(hintText: 'Edit your comment here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await updateComment(commentID, commentController.text);
              Provider.of<VerseProvider>(context, listen: false)
                  .fetchPublicVerses(reset: true, silent: true);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              verse['VerseID'],
              style:
                  const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verse['Content'],
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
                const SizedBox(height: 16),
                Text(
                  verse['Note'],
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(likesCount.toString()),
                    IconButton(
                      icon: const Icon(Icons.thumb_up),
                      onPressed: toggleLike,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.comment),
                      onPressed: () => showAddCommentDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      if (comment['ParentCommentID'] == null ||
                          comment['ParentCommentID'] == 0) {
                        return _buildCommentCard(comment, 1, comments);
                      }
                      return Container();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(
    Map<String, dynamic> comment,
    int depth,
    List<dynamic> allComments,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final lineColor = settings.currentColor;
    final br = Theme.of(context).brightness;

    // layout knobs
    const double edgePad = 8.0; // keep bars away from screen edge
    const double step = 16.0; // indent per depth level
    const double lineW = 5.0; // bar thickness
    const double bubbleGap = 4.0; // last bar → bubble gap
    const double vGap = 12.0; // vertical gap between comments

    // replies of this comment
    final children = allComments
        .where((c) => c['ParentCommentID'] == comment['CommentID'])
        .toList();

    //--------------------------------------------------------------------
    // helper that draws a bar plus its tail for vGap px
    Widget _barWithTail(bool tail) => Column(
          children: [
            Expanded(child: Container(width: lineW, color: lineColor)),
            if (tail) Container(width: lineW, height: vGap, color: lineColor),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(top: vGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //─────────────────  comment row  ──────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: edgePad),

                // draw one bar for each nesting level
                for (int i = 0; i < depth; i++) ...[
                  _barWithTail(true), // ◀─ continuous
                  SizedBox(
                      width: i == depth - 1
                          ? bubbleGap // last gap
                          : step - lineW),
                ],

                // comment bubble
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.zero,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment['Username'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: br == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['Content'],
                          style: TextStyle(
                            color: br == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon:
                                  Icon(Icons.reply, color: lineColor, size: 20),
                              onPressed: () => showAddCommentDialog(
                                context,
                                parentCommentID: comment['CommentID'],
                              ),
                            ),
                            if (comment['UserID'] == settings.userId) ...[
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: lineColor, size: 20),
                                onPressed: () => showEditCommentDialog(
                                  context,
                                  comment['CommentID'],
                                  comment['Content'],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: lineColor, size: 20),
                                onPressed: () =>
                                    _confirmDeleteComment(comment['CommentID']),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          //─────────────────  recursive replies  ────────────────────────
          if (children.isNotEmpty) ...[
            ...children
                .map((c) => _buildCommentCard(c, depth + 1, allComments))
                .toList(),
          ]
        ],
      ),
    );
  }

  void _confirmDeleteComment(int commentID) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await deleteComment(commentID);
              Provider.of<VerseProvider>(context, listen: false)
                  .fetchPublicVerses(reset: true, silent: true);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
