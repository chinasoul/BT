import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bili_tv_app/core/focus/focus_navigation.dart';
import 'package:bili_tv_app/config/app_style.dart';
import 'package:bili_tv_app/services/bilibili_api.dart';
import 'package:bili_tv_app/services/settings_service.dart';
import 'package:bili_tv_app/utils/image_url_utils.dart';
import '../../models/comment.dart';

/// 评论弹窗（Popup 方式，半透明遮罩 + 右侧面板）
class CommentPopup extends StatefulWidget {
  final int aid;
  final VoidCallback onClose;

  const CommentPopup({super.key, required this.aid, required this.onClose});

  @override
  State<CommentPopup> createState() => _CommentPopupState();
}

class _CommentPopupState extends State<CommentPopup> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  final List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;
  String? _nextOffset;
  bool _hasMore = true;
  int _sortMode = 3; // 3=热度, 2=时间

  // Sort cache
  final Map<int, List<Comment>> _cachedComments = {};
  final Map<int, int> _cachedTotalCount = {};
  final Map<int, String?> _cachedNextOffset = {};
  final Map<int, bool> _cachedHasMore = {};

  // Expanded replies
  final Map<int, List<Comment>> _expandedReplies = {};
  final Map<int, int> _replyPages = {};
  final Map<int, bool> _replyHasMore = {};

  // Focus: -1 = sort热度, -2 = sort时间, 0+ = comment items
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _comments.clear();
    _cachedComments.clear();
    _expandedReplies.clear();
    _itemKeys.clear();
    super.dispose();
  }

  Future<void> _loadComments({bool loadMore = false}) async {
    if (loadMore && (!_hasMore || _isLoadingMore)) return;

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    final result = await BilibiliApi.getComments(
      oid: widget.aid,
      mode: _sortMode,
      nextOffset: loadMore ? _nextOffset : null,
    );

    if (!mounted) return;

    setState(() {
      if (!loadMore) {
        _comments.clear();
        _expandedReplies.clear();
        _replyPages.clear();
        _replyHasMore.clear();
      }
      _comments.addAll(result.comments);
      _totalCount = result.totalCount;
      _nextOffset = result.nextOffset;
      _hasMore = result.hasMore;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _toggleReplies(int index) async {
    final comment = _comments[index];
    if (comment.rcount == 0) return;

    if (_expandedReplies.containsKey(comment.rpid)) {
      setState(() {
        _expandedReplies.remove(comment.rpid);
        _replyPages.remove(comment.rpid);
        _replyHasMore.remove(comment.rpid);
      });
    } else {
      final replies = await BilibiliApi.getReplies(
        oid: widget.aid,
        root: comment.rpid,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _expandedReplies[comment.rpid] = replies;
        _replyPages[comment.rpid] = 1;
        _replyHasMore[comment.rpid] = replies.length >= 10;
      });
    }
  }

  Future<void> _loadMoreReplies(int rpid) async {
    if (_replyHasMore[rpid] != true) return;
    final nextPage = (_replyPages[rpid] ?? 1) + 1;
    final replies = await BilibiliApi.getReplies(
      oid: widget.aid,
      root: rpid,
      page: nextPage,
    );
    if (!mounted) return;
    setState(() {
      _expandedReplies[rpid]?.addAll(replies);
      _replyPages[rpid] = nextPage;
      _replyHasMore[rpid] = replies.length >= 10;
    });
  }

  void _switchSort(int mode) {
    if (_sortMode == mode) return;

    if (_comments.isNotEmpty) {
      _cachedComments[_sortMode] = List.from(_comments);
      _cachedTotalCount[_sortMode] = _totalCount;
      _cachedNextOffset[_sortMode] = _nextOffset;
      _cachedHasMore[_sortMode] = _hasMore;
    }

    _sortMode = mode;
    _itemKeys.clear();
    _expandedReplies.clear();
    _replyPages.clear();
    _replyHasMore.clear();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (_cachedComments.containsKey(mode)) {
      setState(() {
        _comments.clear();
        _comments.addAll(_cachedComments[mode]!);
        _totalCount = _cachedTotalCount[mode] ?? 0;
        _nextOffset = _cachedNextOffset[mode];
        _hasMore = _cachedHasMore[mode] ?? true;
        _isLoading = false;
      });
      return;
    }

    _loadComments();
  }

  void _scrollToFocused() {
    if (_comments.isEmpty || _focusedIndex < 0) return;
    if (!_scrollController.hasClients) return;

    if (_focusedIndex == 0) {
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    final key = _itemKeys[_focusedIndex];
    if (key == null) return;

    final itemContext = key.currentContext;
    if (itemContext == null) return;

    final ro = itemContext.findRenderObject() as RenderBox?;
    if (ro == null || !ro.hasSize) return;

    final scrollableState = Scrollable.maybeOf(itemContext);
    if (scrollableState == null) return;

    final position = scrollableState.position;
    final scrollableRO =
        scrollableState.context.findRenderObject() as RenderBox?;
    if (scrollableRO == null || !scrollableRO.hasSize) return;

    final itemInViewport =
        ro.localToGlobal(Offset.zero, ancestor: scrollableRO);
    final viewportHeight = scrollableRO.size.height;
    final itemHeight = ro.size.height;
    final itemTop = itemInViewport.dy;
    final itemBottom = itemTop + itemHeight;

    final revealHeight = itemHeight * 0.5;
    final topBoundary = revealHeight;
    final bottomBoundary = viewportHeight - revealHeight;

    double? targetScrollOffset;

    if (itemBottom > bottomBoundary) {
      targetScrollOffset = position.pixels + (itemBottom - bottomBoundary);
    } else if (itemTop < topBoundary) {
      targetScrollOffset = position.pixels + (itemTop - topBoundary);
    }

    if (targetScrollOffset == null) return;

    final target = targetScrollOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((position.pixels - target).abs() < 4.0) return;
    _scrollController.jumpTo(target);
  }

  static bool _isBackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.browserBack;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Back key: let it propagate to PopScope on VideoDetailScreen
    if (_isBackKey(event)) return KeyEventResult.ignored;

    // Sort buttons area
    if (_focusedIndex < 0) {
      return TvKeyHandler.handleNavigation(
        event,
        onLeft: () {
          if (_focusedIndex == -2) {
            setState(() => _focusedIndex = -1);
            if (SettingsService.focusSwitchTab) {
              _switchSort(3);
            }
          } else {
            widget.onClose();
          }
        },
        onRight: () {
          if (_focusedIndex == -1) {
            setState(() => _focusedIndex = -2);
            if (SettingsService.focusSwitchTab) {
              _switchSort(2);
            }
          }
        },
        onDown: () {
          if (_comments.isNotEmpty) {
            setState(() => _focusedIndex = 0);
            _scrollToFocused();
          }
        },
        onSelect: () {
          _switchSort(_focusedIndex == -1 ? 3 : 2);
        },
        blockUp: true,
      );
    }

    // Comment list: up/down support repeat
    final isKeyDown = event is KeyDownEvent;

    final upDownResult = TvKeyHandler.handleNavigationWithRepeat(
      event,
      onUp: () {
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          _scrollToFocused();
        } else if (isKeyDown) {
          setState(() => _focusedIndex = _sortMode == 3 ? -1 : -2);
        }
      },
      onDown: () {
        if (_focusedIndex < _comments.length - 1) {
          setState(() => _focusedIndex++);
          _scrollToFocused();
          if (_focusedIndex >= _comments.length - 3) {
            _loadComments(loadMore: true);
          }
        }
      },
    );
    if (upDownResult == KeyEventResult.handled) return upDownResult;

    return TvKeyHandler.handleSinglePress(
      event,
      onLeft: () => widget.onClose(),
      onSelect: () {
        if (_focusedIndex >= 0 && _focusedIndex < _comments.length) {
          _toggleReplies(_focusedIndex);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = screenSize.width * 0.35;

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_isBackKey(event)) return KeyEventResult.ignored;
        final result = _handleKeyEvent(node, event);
        if (result == KeyEventResult.handled) return result;
        return KeyEventResult.handled;
      },
      child: Focus(
        focusNode: _focusNode,
        child: Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
            // Panel (right side)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: popupWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final themeColor = SettingsService.themeColor;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.comment_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '评论 $_totalCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFonts.sizeLG,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildSortChip('最热', -1, _sortMode == 3, themeColor),
          const SizedBox(width: 8),
          _buildSortChip('最新', -2, _sortMode == 2, themeColor),
        ],
      ),
    );
  }

  Widget _buildSortChip(
    String label,
    int focusIndex,
    bool isActive,
    Color themeColor,
  ) {
    final isFocused = _focusedIndex == focusIndex;
    return GestureDetector(
      onTap: () => _switchSort(focusIndex == -1 ? 3 : 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isFocused
              ? themeColor.withValues(alpha: 0.6)
              : isActive
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isActive && !isFocused
              ? Border.all(color: Colors.white24, width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isFocused || isActive ? Colors.white : AppColors.textHint,
            fontSize: AppFonts.sizeSM,
            fontWeight: isActive ? AppFonts.semibold : AppFonts.regular,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          '暂无评论',
          style: TextStyle(color: AppColors.textHint, fontSize: AppFonts.sizeMD),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        _itemKeys[index] ??= GlobalKey();
        return _buildCommentItem(_comments[index], _focusedIndex == index, index);
      },
    );
  }

  Widget _buildCommentItem(Comment comment, bool isFocused, int index) {
    final themeColor = SettingsService.themeColor;
    final hasReplies = comment.rcount > 0;
    final isExpanded = _expandedReplies.containsKey(comment.rpid);
    final replies = _expandedReplies[comment.rpid] ?? [];

    return Container(
      key: _itemKeys[index],
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isFocused
            ? themeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: ImageUrlUtils.getResizedUrl(
                      comment.avatar,
                      width: 64,
                    ),
                    width: 32,
                    height: 32,
                    memCacheWidth: 64,
                    memCacheHeight: 64,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(width: 32, height: 32, color: Colors.white12),
                    errorWidget: (_, _, _) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.white12,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white24,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.uname,
                              style: TextStyle(
                                color: isFocused ? themeColor : Colors.white60,
                                fontSize: AppFonts.sizeSM,
                                fontWeight: AppFonts.medium,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            comment.timeText,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: AppFonts.sizeXS,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFonts.sizeSM,
                          height: 1.4,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.thumb_up_outlined,
                            color: AppColors.textDisabled,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            comment.likeText,
                            style: const TextStyle(
                              color: AppColors.textDisabled,
                              fontSize: AppFonts.sizeXS,
                            ),
                          ),
                          if (hasReplies) ...[
                            const SizedBox(width: 16),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: isFocused
                                  ? themeColor
                                  : AppColors.textDisabled,
                              size: 15,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              isExpanded
                                  ? '收起回复'
                                  : '${comment.rcount}条回复',
                              style: TextStyle(
                                color: isFocused
                                    ? themeColor
                                    : AppColors.textDisabled,
                                fontSize: AppFonts.sizeXS,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded && replies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 52, right: 12, bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  for (final reply in replies) _buildReplyItem(reply),
                  if (_replyHasMore[comment.rpid] == true)
                    GestureDetector(
                      onTap: () => _loadMoreReplies(comment.rpid),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '查看更多回复',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: AppFonts.sizeSM,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Comment reply) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: ImageUrlUtils.getResizedUrl(reply.avatar, width: 48),
              width: 20,
              height: 20,
              memCacheWidth: 48,
              memCacheHeight: 48,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(width: 20, height: 20, color: Colors.white12),
              errorWidget: (_, _, _) =>
                  Container(width: 20, height: 20, color: Colors.white12),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${reply.uname}  ',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: AppFonts.sizeSM,
                      fontWeight: AppFonts.medium,
                    ),
                  ),
                  TextSpan(
                    text: reply.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppFonts.sizeSM,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
