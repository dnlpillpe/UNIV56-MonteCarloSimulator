import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/llm_clients.dart';
import '../data/repositories.dart';
import '../domain/analyst/analyst_engine.dart';
import '../domain/analyst/hybrid_analyst.dart';
import '../domain/progress/progress.dart';
import '../domain/sim/model_spec.dart';
import '../domain/sim/result_summary.dart';
import '../domain/sim/simulation_engine.dart';
import '../domain/sim/templates.dart';

/// Se sobreescribe en main() con la instancia real (y en las pruebas con
/// valores simulados).
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider debe sobreescribirse en main()');
});

final progressRepoProvider = Provider((ref) => ProgressRepository(ref.watch(sharedPrefsProvider)));
final modelRepoProvider = Provider((ref) => ModelRepository(ref.watch(sharedPrefsProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(sharedPrefsProvider)));

// ------------------------------------------------------------------ progreso
class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() => ref.read(progressRepoProvider).load();

  void _set(ProgressState s) {
    state = s;
    ref.read(progressRepoProvider).save(s);
  }

  void completeLesson(String id) {
    if (state.lessonsDone.contains(id)) return;
    _set(state.copyWith(lessonsDone: {...state.lessonsDone, id}));
  }

  void recordPrediction(String experimentId, bool correct) {
    if (state.predictions.containsKey(experimentId)) return; // solo la primera
    _set(state.copyWith(predictions: {...state.predictions, experimentId: correct}));
  }

  void completeExperiment(String id) {
    if (state.experimentsDone.contains(id)) return;
    _set(state.copyWith(experimentsDone: {...state.experimentsDone, id}));
  }

  /// Registra un intento de ejercicio (o paso de caso).
  void recordAnswer({
    required String exerciseId,
    required double score,
    required Set<String> committed,
    required Set<String> targets,
  }) {
    final best = {...state.exerciseScores};
    final prev = best[exerciseId] ?? 0;
    if (score > prev) best[exerciseId] = score;
    final first = {...state.firstTryScores};
    first.putIfAbsent(exerciseId, () => score);
    final avoided = score >= 0.999 ? targets : <String>{};
    _set(state.copyWith(
      exerciseScores: best,
      firstTryScores: first,
      confusionScores: updateDiagnosis(state.confusionScores, committed: committed, avoided: avoided),
    ));
  }

  /// Práctica generativa: alimenta el diagnóstico, no el dominio.
  void recordGenerated({required bool correct, required Set<String> committed}) {
    _set(state.copyWith(
      generatedAnswered: state.generatedAnswered + 1,
      generatedCorrect: state.generatedCorrect + (correct ? 1 : 0),
      confusionScores: updateDiagnosis(state.confusionScores, committed: committed, avoided: const {}),
    ));
  }

  void countSimulation() => _set(state.copyWith(simulationsRun: state.simulationsRun + 1));

  void reset() {
    state = const ProgressState();
    ref.read(progressRepoProvider).clear();
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);

// ---------------------------------------------------------------- simulador
class SimulatorState {
  const SimulatorState({
    required this.spec,
    this.iterations = 10000,
    this.seed = 17,
    this.summary,
    this.report,
    this.error,
    this.dirty = false,
    this.revision = 0,
  });

  final ModelSpec spec;

  /// Aumenta al cargar un modelo nuevo (para reiniciar los formularios).
  final int revision;
  final int iterations;
  final int seed;
  final ResultSummary? summary;
  final AnalystReport? report;
  final String? error;

  /// El modelo cambió desde la última corrida.
  final bool dirty;

  SimulatorState copyWith({
    ModelSpec? spec,
    int? iterations,
    int? seed,
    ResultSummary? summary,
    AnalystReport? report,
    String? error,
    bool clearError = false,
    bool clearResults = false,
    bool? dirty,
  }) =>
      SimulatorState(
        spec: spec ?? this.spec,
        iterations: iterations ?? this.iterations,
        seed: seed ?? this.seed,
        summary: clearResults ? null : (summary ?? this.summary),
        report: clearResults ? null : (report ?? this.report),
        error: clearError ? null : (error ?? this.error),
        dirty: dirty ?? this.dirty,
        revision: revision,
      );
}

class SimulatorNotifier extends Notifier<SimulatorState> {
  @override
  SimulatorState build() {
    final saved = ref.read(modelRepoProvider).load();
    return SimulatorState(spec: saved ?? modelTemplates.first);
  }

  void loadModel(ModelSpec spec) {
    state = SimulatorState(spec: spec, iterations: state.iterations, seed: state.seed, revision: state.revision + 1);
    ref.read(modelRepoProvider).save(spec);
  }

  void updateSpec(ModelSpec spec) {
    state = state.copyWith(spec: spec, dirty: state.summary != null, clearError: true);
    ref.read(modelRepoProvider).save(spec);
  }

  void setIterations(int n) => state = state.copyWith(iterations: n, dirty: state.summary != null);
  void setSeed(int s) => state = state.copyWith(seed: s, dirty: state.summary != null);

  /// Valida sin simular: devuelve el error o null.
  String? validate() {
    try {
      CompiledModel.compile(state.spec);
      return null;
    } on ModelError catch (e) {
      return e.message;
    }
  }

  void run() {
    try {
      final run = const SimulationEngine().run(state.spec, iterations: state.iterations, seed: state.seed);
      final summary = ResultSummary.of(run);
      final report = const AnalystEngine().analyze(summary);
      state = state.copyWith(summary: summary, report: report, clearError: true, dirty: false);
      ref.read(progressProvider.notifier).countSimulation();
    } on ModelError catch (e) {
      state = state.copyWith(error: e.message, clearResults: true);
    }
  }
}

final simulatorProvider = NotifierProvider<SimulatorNotifier, SimulatorState>(SimulatorNotifier.new);

// ------------------------------------------------------------------ analista
class AiSettingsNotifier extends Notifier<AiSettings> {
  @override
  AiSettings build() => ref.read(settingsRepoProvider).load();

  void save(AiSettings s) {
    state = s;
    ref.read(settingsRepoProvider).save(s);
  }
}

final aiSettingsProvider = NotifierProvider<AiSettingsNotifier, AiSettings>(AiSettingsNotifier.new);

/// Generador de IA (null si no está configurado). Las pruebas lo
/// sobreescriben con uno simulado.
final textGeneratorProvider = Provider<TextGenerator?>((ref) => generatorFor(ref.watch(aiSettingsProvider)));

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.source, this.note, this.lessonId});
  final bool fromUser;
  final String text;
  final AnswerSource? source;
  final String? note;
  final String? lessonId;
}

class ChatState {
  const ChatState({this.messages = const [], this.busy = false});
  final List<ChatMessage> messages;
  final bool busy;
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    // Una corrida nueva reinicia la conversación.
    ref.watch(simulatorProvider.select((s) => s.report));
    return const ChatState();
  }

  Future<void> ask(String question) async {
    final report = ref.read(simulatorProvider).report;
    final q = question.trim();
    if (report == null || q.isEmpty || state.busy) return;
    state = ChatState(messages: [...state.messages, ChatMessage(fromUser: true, text: q)], busy: true);
    final ans = await const HybridAnalyst().answer(q, report, ai: ref.read(textGeneratorProvider));
    state = ChatState(
      messages: [
        ...state.messages,
        ChatMessage(fromUser: false, text: ans.text, source: ans.source, note: ans.note, lessonId: ans.lessonId),
      ],
      busy: false,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

/// Pestaña activa del armazón principal.
class TabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final tabProvider = NotifierProvider<TabNotifier, int>(TabNotifier.new);
