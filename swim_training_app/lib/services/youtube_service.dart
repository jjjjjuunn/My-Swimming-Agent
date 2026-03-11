import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
import '../models/video_item.dart';

class YouTubeService {
  // YouTube Data API v3 키
  // https://console.cloud.google.com/
  static const String _apiKey = 'AIzaSyAvlUatf0PF9YKWsM1xZ7vcKE1-VwGCWsM';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  
  // Google Translator 인스턴스
  final GoogleTranslator _translator = GoogleTranslator();

  // 한글을 영어로 실시간 번역
  Future<String> _translateKoreanToEnglish(String text) async {
    try {
      print('🔄 Translating: $text');
      final translation = await _translator.translate(text, from: 'ko', to: 'en');
      print('✅ Translation result: ${translation.text}');
      return translation.text;
    } catch (e) {
      print('❌ Translation error: $e');
      // 번역 실패 시 원본 텍스트 반환
      return text;
    }
  }

  // 수영 관련 키워드 체크
  bool _isSwimmingRelated(String query) {
    final lowerQuery = query.toLowerCase();
    
    // 수영 관련 한국어 키워드
    final koreanKeywords = [
      '수영', '자유형', '접영', '배영', '평영', '돌핀킥', '킥', 
      '스트로크', '호흡', '턴', '풀', '영법', '드릴', '글라이드',
      '플러터', '웨지', '휩킥', '입수', '캐치', '리커버리'
    ];
    
    // 수영 관련 영어 키워드
    final englishKeywords = [
      'swim', 'freestyle', 'butterfly', 'backstroke', 'breaststroke',
      'dolphin', 'kick', 'stroke', 'breathing', 'turn', 'pool',
      'crawl', 'drill', 'glide', 'flutter', 'technique', 'training'
    ];
    
    // 키워드가 하나라도 포함되어 있으면 true
    for (var keyword in [...koreanKeywords, ...englishKeywords]) {
      if (lowerQuery.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  Future<Map<String, dynamic>> searchVideos(
    String query, {
    int maxResults = 10,
    bool preferInternational = false, // 해외 영상 선호 여부
    String? pageToken, // 페이지네이션용 토큰
  }) async {
    try {
      print('🔍 Searching for: $query');
      print('🌍 International preference: $preferInternational');
      
      String searchQuery = query;
      
      // 해외 영상 선호 & 한글 포함 시 번역
      if (preferInternational && _containsKorean(query)) {
        searchQuery = await _translateKoreanToEnglish(query);
        print('🔄 Translated: $query → $searchQuery');
      }
      
      // 모든 검색어에 swimming 추가 (더 정확한 결과)
      if (!searchQuery.toLowerCase().contains('swimming')) {
        searchQuery = '$searchQuery swimming';
        print('➕ Added "swimming" filter');
      }
      
      // 해외 영상 선호 시 영어권 영상 우선
      String regionCode = preferInternational ? 'US' : 'KR';
      String relevanceLanguage = preferInternational ? 'en' : 'ko';
      
      // URL 생성 (pageToken이 있으면 추가)
      String urlString = '$_baseUrl/search?part=snippet&q=$searchQuery&type=video&maxResults=$maxResults&key=$_apiKey&regionCode=$regionCode&relevanceLanguage=$relevanceLanguage';
      if (pageToken != null && pageToken.isNotEmpty) {
        urlString += '&pageToken=$pageToken';
      }
      final url = Uri.parse(urlString);

      print('📡 Region: $regionCode, Language: $relevanceLanguage');
      
      final response = await http.get(url);
      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        final String? nextPageToken = data['nextPageToken'];
        
        print('✅ Found ${items.length} videos');
        if (nextPageToken != null) {
          print('📄 Next page token: $nextPageToken');
        }
        
        final videos = items.map((item) => VideoItem.fromJson(item)).toList();
        return {
          'videos': videos,
          'nextPageToken': nextPageToken,
        };
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching videos: $e');
      return {'videos': [], 'nextPageToken': null};
    }
  }

  // 한글이 포함되어 있는지 체크
  bool _containsKorean(String text) {
    return RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]').hasMatch(text);
  }

  // 특정 수영 기술에 대한 맞춤형 검색
  Future<Map<String, dynamic>> searchSwimTechnique({
    required String stroke, // 영법 (butterfly, freestyle, etc.)
    required String technique, // 기술 (dolphin kick, breathing, etc.)
    int maxResults = 10,
  }) async {
    final query = '$stroke $technique';
    return searchVideos(query, maxResults: maxResults);
  }
}
