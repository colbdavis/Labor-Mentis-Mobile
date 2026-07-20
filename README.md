# Labor Mentis

Offline Flutter prototype of a configurable quiz and minigame engine.

The prototype includes a few built-in quiz packs and four playable modes:

- multiple choice;
- true or false;
- text answer;
- matching pairs.

The **Scores** screen calculates the overall average and groups results by
category. Content is currently defined in Dart to keep the first prototype
simple; the next step is importing validated YAML quiz packs locally.

## Run

```zsh
flutter run
```

To check the project:

```zsh
flutter analyze
flutter test
```
