import '../sim/model_spec.dart';

/// Modelos del contenido educativo (inmutables, definidos como `const`).

class Module {
  const Module({
    required this.id,
    required this.number,
    required this.title,
    required this.theme,
    required this.question,
    required this.summary,
  });

  final String id;
  final int number;
  final String title;

  /// Tema pedido: azar, riesgo o estimaciones.
  final String theme;

  /// Pregunta que el módulo responde.
  final String question;
  final String summary;
}

class LessonCard {
  const LessonCard({
    required this.title,
    required this.body,
    this.formula,
    this.keyIdea,
    this.check,
  });

  final String title;
  final String body;
  final String? formula;
  final String? keyIdea;

  /// Pregunta rápida de autocomprobación (no puntúa).
  final QuickCheck? check;
}

class QuickCheck {
  const QuickCheck({required this.question, required this.options, required this.correct, required this.explanation});
  final String question;
  final List<String> options;
  final int correct;
  final String explanation;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.goal,
    required this.cards,
    this.labId,
  });

  final String id;
  final String moduleId;
  final String title;
  final String goal;
  final List<LessonCard> cards;

  /// Laboratorio donde se practica lo aprendido.
  final String? labId;
}

class Lab {
  const Lab({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.subtitle,
    required this.experimentIds,
  });

  final String id;
  final String moduleId;
  final String title;
  final String subtitle;
  final List<String> experimentIds;
}

/// Alternativa de predicción de un experimento.
class PredictionOption {
  const PredictionOption(this.text, {this.correct = false, this.confusion});
  final String text;
  final bool correct;

  /// Confusión que revela elegirla (solo informativa: la predicción
  /// nunca resta, es la intuición inicial).
  final String? confusion;
}

/// Definición de un experimento: Predice → Simula → Explica.
class ExperimentDef {
  const ExperimentDef({
    required this.id,
    required this.labId,
    required this.title,
    required this.setup,
    required this.prediction,
    required this.options,
    required this.minSamples,
    required this.finding,
    required this.explanation,
    this.remedyFor = const [],
  });

  final String id;
  final String labId;
  final String title;

  /// Qué se simula y qué se puede manipular.
  final String setup;
  final String prediction;
  final List<PredictionOption> options;

  /// Repeticiones (o acciones) mínimas antes de desbloquear el hallazgo.
  final int minSamples;

  /// Hallazgo con cifras `{{id}}` y observaciones `[[clave]]` de la corrida.
  final String finding;
  final String explanation;

  /// Confusiones que este experimento remedia.
  final List<String> remedyFor;
}

enum ExerciseType { choice, numeric, decision, ordering }

class Option {
  const Option(this.text, {this.correct = false, required this.feedback, this.confusion});
  final String text;
  final bool correct;
  final String feedback;
  final String? confusion;
}

/// Error numérico reconocible: si el estudiante escribe este número, la app
/// sabe qué confusión lo produjo.
class WrongPattern {
  const WrongPattern({required this.figure, required this.confusion, required this.feedback});
  final String figure;
  final String confusion;
  final String feedback;
}

class Exercise {
  const Exercise({
    required this.id,
    required this.moduleId,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.justifications = const [],
    this.answerFigure,
    this.answerIsPercent = false,
    this.relTolerance = 0.02,
    this.unit = '',
    this.wrongPatterns = const [],
    this.steps = const [],
    required this.explanation,
    this.targets = const [],
  });

  final String id;
  final String moduleId;
  final ExerciseType type;
  final String prompt;

  /// Alternativas (choice) o decisión (decision).
  final List<Option> options;

  /// Justificaciones (solo decision): regla 60/40.
  final List<Option> justifications;

  /// Respuesta numérica: identificador de cifra del registro.
  final String? answerFigure;

  /// La respuesta se escribe como porcentaje (37,8) y la cifra es una
  /// proporción (0,378).
  final bool answerIsPercent;
  final double relTolerance;
  final String unit;
  final List<WrongPattern> wrongPatterns;

  /// Pasos en el orden correcto (ordering); la app los baraja.
  final List<String> steps;
  final String explanation;

  /// Confusiones que el ítem pone a prueba (evitarlas resta en el diagnóstico).
  final List<String> targets;
}

class CaseStudy {
  const CaseStudy({
    required this.id,
    required this.career,
    required this.title,
    required this.context,
    required this.steps,
    this.model,
    required this.closing,
  });

  final String id;
  final String career;
  final String title;
  final String context;
  final List<Exercise> steps;

  /// Modelo para abrir el caso en el simulador (si es expresable).
  final ModelSpec? model;
  final String closing;
}

class Confusion {
  const Confusion({
    required this.id,
    required this.name,
    required this.description,
    required this.remedy,
    this.remedyLessonId,
    this.remedyExperimentId,
  });

  final String id;
  final String name;
  final String description;
  final String remedy;
  final String? remedyLessonId;
  final String? remedyExperimentId;
}

class GlossaryTerm {
  const GlossaryTerm(this.term, this.definition, {this.example});
  final String term;
  final String definition;
  final String? example;
}
