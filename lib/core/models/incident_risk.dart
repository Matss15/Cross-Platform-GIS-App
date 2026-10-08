part of '../../app.dart';

class IncidentRiskPrediction {
  const IncidentRiskPrediction({
    required this.level,
    required this.score,
    required this.reason,
  });

  final String level;
  final int score;
  final String reason;
}

/// A small, explainable decision tree for the initial deployment.
/// Replace the thresholds with a trained model after enough labelled incidents
/// are available. It never replaces dispatcher or admin judgement.
IncidentRiskPrediction predictIncidentRisk({
  required Map<String, dynamic> incident,
  int recentBarangayIncidents = 0,
}) {
  final priority = textField(incident, 'priority', 'Medium').toLowerCase();
  final type = textField(incident, 'type').toLowerCase();
  var score = switch (priority) {
    // Critical alone reaches the High threshold, whatever the type.
    'critical' => 6,
    'high' => 3,
    'medium' => 2,
    _ => 1,
  };

  if (type.contains('structure') || type.contains('chemical')) score += 2;
  if (type.contains('vehicle') || type.contains('electrical')) score += 1;
  if (recentBarangayIncidents >= 5) score += 2;
  if (recentBarangayIncidents >= 10) score += 1;

  if (score >= 6) {
    return IncidentRiskPrediction(
      level: 'High',
      score: score,
      reason: 'High severity, incident type, or repeated barangay reports.',
    );
  }
  if (score >= 4) {
    return IncidentRiskPrediction(
      level: 'Medium',
      score: score,
      reason: 'Moderate severity or contributing incident conditions.',
    );
  }
  return IncidentRiskPrediction(
    level: 'Low',
    score: score,
    reason: 'No high-risk decision-tree condition was detected.',
  );
}
