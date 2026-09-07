import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// A simple, explainable way to guess where an item probably is,
// based on its recent location history. This isn't real machine
// learning — it's a weighted-recency heuristic — but it gives
// genuinely useful output without needing a trained model.
class PredictionResult {
  final double latitude;
  final double longitude;
  final double confidencePercent;
  final DateTime lastSeenAt;

  PredictionResult({
    required this.latitude,
    required this.longitude,
    required this.confidencePercent,
    required this.lastSeenAt,
  });
}

class PredictionService {
  // How close two points need to be (in degrees, roughly ~100m) to be
  // considered "the same place" for clustering purposes.
  static const double _sameSpotThreshold = 0.001;

  Future<List<PredictionResult>> predictLocation(String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .collection('locationHistory')
        .orderBy('timestamp', descending: true)
        .limit(30) // recent history is enough, no need to scan everything
        .get();

    if (snapshot.docs.isEmpty) return [];

    // Step 1: group nearby check-ins into rough "spots".
    final List<_LocationCluster> clusters = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      _LocationCluster? matchingCluster;
      for (final cluster in clusters) {
        final latDiff = (cluster.latitude - lat).abs();
        final lngDiff = (cluster.longitude - lng).abs();
        if (latDiff < _sameSpotThreshold && lngDiff < _sameSpotThreshold) {
          matchingCluster = cluster;
          break;
        }
      }

      if (matchingCluster != null) {
        matchingCluster.visitCount++;
        if (timestamp.isAfter(matchingCluster.mostRecentVisit)) {
          matchingCluster.mostRecentVisit = timestamp;
        }
      } else {
        clusters.add(_LocationCluster(
          latitude: lat,
          longitude: lng,
          visitCount: 1,
          mostRecentVisit: timestamp,
        ));
      }
    }

    // Step 2: score each cluster. More visits = more likely. More
    // recent = more likely. We combine both into one simple weight.
    final now = DateTime.now();
    for (final cluster in clusters) {
      final hoursSinceSeen = now.difference(cluster.mostRecentVisit).inHours;
      // Recency score fades over about 3 days (72 hours).
      final recencyScore = (1 - (hoursSinceSeen / 72)).clamp(0.0, 1.0);
      final frequencyScore = cluster.visitCount / snapshot.docs.length;
      cluster.rawScore = (recencyScore * 0.6) + (frequencyScore * 0.4);
    }

    // Step 3: turn raw scores into percentages that add up to 100%.
    final totalScore = clusters.fold<double>(0, (sum, c) => sum + c.rawScore);

    final results = clusters.map((cluster) {
      final percent = totalScore > 0 ? (cluster.rawScore / totalScore) * 100 : 0.0;
      return PredictionResult(
        latitude: cluster.latitude,
        longitude: cluster.longitude,
        confidencePercent: percent,
        lastSeenAt: cluster.mostRecentVisit,
      );
    }).toList();

    // Highest confidence first.
    results.sort((a, b) => b.confidencePercent.compareTo(a.confidencePercent));

    return results;
  }
}

class _LocationCluster {
  final double latitude;
  final double longitude;
  int visitCount;
  DateTime mostRecentVisit;
  double rawScore = 0;

  _LocationCluster({
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.mostRecentVisit,
  });
}