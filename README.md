# Labor Mentis

Offline Flutter prototype of a configurable quiz and minigame engine.

The prototype includes a few built-in quiz packs and four playable modes:

- multiple choice;
- true or false;
- text answer;
- matching pairs.

The **Scores** screen calculates the overall average and groups results by
category. Users can import validated YAML quiz packs from local storage; packs
are kept in the app's private storage and remain available after restart.

The planned YAML format is documented in
[YAML Quiz Pack Guide](docs/YAML_QUIZ_GUIDE.md).

## Mirrors

- [GitHub](https://github.com/colbdavis/Labor-Mentis-Mobile)
- [Codeberg](https://codeberg.org/colbdavis/Labor-Mentis-Mobile)

## Run

```zsh
flutter run
```

To check the project:

```zsh
flutter analyze
flutter test
```

## License

This project is licensed under the [MIT License](LICENSE).
