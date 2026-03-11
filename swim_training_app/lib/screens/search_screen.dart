import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/youtube_service.dart';
import '../services/search_history_service.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final YouTubeService _youtubeService = YouTubeService();
  final SearchHistoryService _historyService = SearchHistoryService();
  List<VideoItem> _videos = [];
  List<SearchHistoryItem> _searchHistory = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  bool _preferInternational = false; // 해외 영상 선호 여부
  bool _showSearchHistory = false; // 검색 기록 드롭다운 표시 여부
  String? _nextPageToken; // 다음 페이지 토큰
  String _currentQuery = ''; // 현재 검색어

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
    _loadSearchHistory();
  }

  void _onFocusChange() {
    setState(() {
      _showSearchHistory = _searchFocusNode.hasFocus && _searchHistory.isNotEmpty;
    });
  }

  Future<void> _loadSearchHistory() async {
    try {
      final history = await _historyService.getSearchHistory(limit: 20);
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      // 로드 실패 시 무시
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // 스크롤이 하단 근처에 도달하면 다음 페이지 로드
      if (!_isLoadingMore && _nextPageToken != null) {
        _loadMoreVideos();
      }
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 검색 기록 저장
    await _historyService.saveSearchQuery(query);
    _loadSearchHistory(); // 기록 새로고침

    // 검색 시 드롭다운 닫기 & 포커스 해제
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchHistory = false;
      _isLoading = true;
      _hasSearched = true;
      _currentQuery = query;
    });

    try {
      final result = await _youtubeService.searchVideos(
        query,
        maxResults: 50,
        preferInternational: _preferInternational,
      );
      setState(() {
        _videos = result['videos'] as List<VideoItem>;
        _nextPageToken = result['nextPageToken'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || _nextPageToken == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _youtubeService.searchVideos(
        _currentQuery,
        maxResults: 50,
        preferInternational: _preferInternational,
        pageToken: _nextPageToken,
      );
      setState(() {
        _videos.addAll(result['videos'] as List<VideoItem>);
        _nextPageToken = result['nextPageToken'] as String?;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '영상 검색',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '전 세계 수영 영상을 검색하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 한국/해외 토글
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _preferInternational = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: !_preferInternational
                                    ? AppTheme.primaryGradient
                                    : null,
                                color: _preferInternational
                                    ? AppTheme.cardColor
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🇰🇷',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '한국 영상',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: !_preferInternational
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _preferInternational = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _preferInternational
                                    ? AppTheme.primaryGradient
                                    : null,
                                color: !_preferInternational
                                    ? AppTheme.cardColor
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🌍',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '해외 영상',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: _preferInternational
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 검색 바 + 드롭다운
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: _showSearchHistory 
                                ? const BorderRadius.vertical(top: Radius.circular(16))
                                : BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.search,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: '검색어를 입력하세요 (예: 돌핀킥, butterfly)',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onTap: () {
                                    // 검색창 탭 시 드롭다운 표시
                                    if (_searchHistory.isNotEmpty) {
                                      setState(() {
                                        _showSearchHistory = true;
                                      });
                                    }
                                  },
                                  onSubmitted: (_) => _search(),
                                ),
                              ),
                              GestureDetector(
                                onTap: _search,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '검색',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 검색 기록 드롭다운
                        if (_showSearchHistory)
                          _buildSearchHistoryDropdown(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _preferInternational
                          ? '💡 한글로 검색하면 자동으로 영어로 번역해요'
                          : '💡 한국 영상 위주로 검색해요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
                ), // SingleChildScrollView
              ), // Flexible
              
              // 검색 결과
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
              '전 세계 영상을 검색하는 중...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildSearchHistorySection();
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 검색어로 시도해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return _buildVideoCard(video);
            },
          ),
        ),
        if (_isLoadingMore)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '더 많은 영상 로딩 중...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVideoCard(VideoItem video) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(video: video),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      video.thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 영상 정보
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          video.channelTitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistorySection() {
    // 검색 전 기본 화면 (검색 기록은 드롭다운으로 이동)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.search,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '원하는 영상을 검색해보세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              '한국어나 영어로 검색하면\n전 세계 수영 영상을 찾아드립니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// YouTube 스타일 검색 기록 드롭다운
  Widget _buildSearchHistoryDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 최근 검색어 + 전체 삭제
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 검색어',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _showDeleteAllConfirmation();
                  },
                  child: Text(
                    '전체 삭제',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          // 검색 기록 리스트
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchHistory.length > 10 ? 10 : _searchHistory.length,
              itemBuilder: (context, index) {
                final item = _searchHistory[index];
                return _buildDropdownHistoryItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownHistoryItem(SearchHistoryItem item) {
    return GestureDetector(
      onTap: () {
        _searchController.text = item.query;
        _search();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: Colors.white.withOpacity(0.4),
              size: 16,
            ),
            const SizedBox(width: 10),
            // 검색어 텍스트
            Expanded(
              child: Text(
                item.query,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 개별 삭제 버튼 (X)
            GestureDetector(
              onTap: () async {
                await _historyService.deleteSearchQuery(item.id);
                await _loadSearchHistory();
                if (_searchHistory.isEmpty) {
                  setState(() {
                    _showSearchHistory = false;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ),
            ),
            // 검색어 채우기 버튼 (화살표)
            GestureDetector(
              onTap: () {
                _searchController.text = item.query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: item.query.length),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.north_west,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '전체 삭제',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '모든 검색 기록을 삭제하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _historyService.deleteAllSearchHistory();
              _loadSearchHistory();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
