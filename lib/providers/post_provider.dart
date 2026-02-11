import 'package:flutter/foundation.dart';
import '../core/extensions/exception_extensions.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../core/errors/error_mapper.dart';
import '../core/errors/app_exception.dart';

class PostProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _error;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all posts
  Future<void> fetchPosts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _posts = await _apiService.getPosts();
      _error = null;
    } catch (e) {
      _error = e.userMessage;
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch posts by user ID
  Future<void> fetchPostsByUser(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _posts = await _apiService.getPostsByUser(userId);
      _error = null;
    } catch (e) {
      _error = e.userMessage;
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new post
  Future<void> addPost(Post post) async {
    try {
      final newPost = await _apiService.createPost(post);
      _posts.insert(0, newPost);
      notifyListeners();
    } catch (e, stack) {
      final appException = ErrorMapper.map(e, stack);
      _error = appException.userMessage;
      notifyListeners();
      throw appException; // Re-throw for UI to handle
    }
  }

  // Update a post
  Future<void> updatePost(Post post) async {
    try {
      final updatedPost = await _apiService.updatePost(post);
      final index = _posts.indexWhere((p) => p.id == updatedPost.id);
      if (index != -1) {
        _posts[index] = updatedPost;
        notifyListeners();
      }
    } catch (e, stack) {
      final appException = ErrorMapper.map(e, stack);
      _error = appException.userMessage;
      notifyListeners();
      throw appException; // Re-throw for UI to handle
    }
  }

  // Delete a post
  Future<void> deletePost(int id) async {
    try {
      await _apiService.deletePost(id);
      _posts.removeWhere((post) => post.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.userMessage;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
