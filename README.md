# Labor Mentis

Prototipo Flutter offline di un motore per quiz e minigiochi configurabili.

Al momento include pochi quiz dimostrativi e quattro modalità giocabili:

- scelta multipla;
- vero/falso;
- risposta testuale;
- collegamento fra coppie.

La schermata **Punteggi** calcola la media delle risposte corrette nella
sessione corrente. I contenuti sono per ora definiti in Dart per tenere il
primo prototipo semplice; il prossimo passo sarà importare pacchetti YAML
validati localmente.

## Avvio

```zsh
flutter run
```

Per controllare il progetto:

```zsh
flutter analyze
flutter test
```
