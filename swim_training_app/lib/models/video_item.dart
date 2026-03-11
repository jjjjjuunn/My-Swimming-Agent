class VideoItem {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String description;

  VideoItem({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.description,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final thumbnails = json['snippet']['thumbnails'];
    // 가능한 가장 높은 화질의 썸네일 선택 (maxres > high > medium)
    String thumbnailUrl = '';
    if (thumbnails['maxres'] != null) {
      thumbnailUrl = thumbnails['maxres']['url'];
    } else if (thumbnails['high'] != null) {
      thumbnailUrl = thumbnails['high']['url'];
    } else if (thumbnails['medium'] != null) {
      thumbnailUrl = thumbnails['medium']['url'];
    } else {
      thumbnailUrl = thumbnails['default']['url'] ?? '';
    }
    
    return VideoItem(
      videoId: json['id']['videoId'] ?? '',
      title: json['snippet']['title'] ?? '',
      channelTitle: json['snippet']['channelTitle'] ?? '',
      thumbnailUrl: thumbnailUrl,
      description: json['snippet']['description'] ?? '',
    );
  }
}
