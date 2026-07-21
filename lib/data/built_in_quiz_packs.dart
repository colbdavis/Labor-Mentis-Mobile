import '../models/game_mode.dart';
import '../models/quiz_pack.dart';
import '../models/quiz_question.dart';

const builtInQuizPacks = [
  QuizPack(
    id: 'geography-capitals-1',
    version: 1,
    title: 'World capitals',
    category: 'Geography',
    mode: GameMode.multipleChoice,
    questions: [
      QuizQuestion(
        prompt: 'What is the capital of Portugal?',
        options: ['Madrid', 'Lisbon', 'Porto', 'Barcelona'],
        correctOption: 1,
      ),
      QuizQuestion(
        prompt: 'Which city is the capital of Canada?',
        options: ['Toronto', 'Vancouver', 'Ottawa', 'Montréal'],
        correctOption: 2,
      ),
      QuizQuestion(
        prompt: 'What is the capital of Australia?',
        options: ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
        correctOption: 2,
      ),
    ],
  ),
  QuizPack(
    id: 'science-true-false-1',
    version: 1,
    title: 'Essential science',
    category: 'Science',
    mode: GameMode.trueFalse,
    questions: [
      QuizQuestion(
        prompt: 'Water boils at 100 °C at sea level.',
        correctOption: 0,
      ),
      QuizQuestion(prompt: 'The Sun is a planet.', correctOption: 1),
      QuizQuestion(prompt: 'Plants absorb carbon dioxide.', correctOption: 0),
    ],
  ),
  QuizPack(
    id: 'italian-words-1',
    version: 1,
    title: 'Italian words',
    category: 'Italian language',
    mode: GameMode.text,
    questions: [
      QuizQuestion(
        prompt: 'What is the plural of “uovo”?',
        acceptedAnswers: ['uova'],
      ),
      QuizQuestion(
        prompt: 'What do you call a word with the opposite meaning?',
        acceptedAnswers: ['contrario', 'antonimo'],
      ),
      QuizQuestion(
        prompt: 'Complete the Italian expression: “né carne né …”',
        acceptedAnswers: ['pesce'],
      ),
    ],
  ),
  QuizPack(
    id: 'literature-matching-1',
    version: 1,
    title: 'Authors and works',
    category: 'Literature',
    mode: GameMode.matching,
    questions: [
      QuizQuestion(
        prompt: 'Match each author with their work.',
        pairs: [
          MatchPair('Dante', 'Divina Commedia'),
          MatchPair('Manzoni', 'I Promessi Sposi'),
          MatchPair('Leopardi', 'L’infinito'),
        ],
      ),
    ],
  ),
];
