# OpenAIs "agentic software factory" gegen ytstack gelesen

Stand: 2026-11-13, ytstack auf dem Branch `spec-and-bounded-work` (0.5.0 plus M022 Technical Spec, M023 Bounded Work, M024 Coordinator Mode, Pull Request 37).

## Quellenlage: was gelesen wurde und was nicht

| Quelle | Gelesen | Belastbarkeit |
|---|---|---|
| Gergely Orosz, "Inside OpenAI's agentic software factory", The Pragmatic Engineer, 2026-09-15 | Abschnitte 1 bis 3 im Volltext (frei zugänglich). **Abschnitte 4 bis 7 liegen hinter der Bezahlschranke und wurden nicht gelesen**: Werkzeuge und Praktiken, Harness-Effizienz, Infrastruktur, API-Zuverlässigkeit, Wandel des Berufs. Von ihnen ist nur die Inhaltsangabe am Artikelanfang bekannt. | Bericht eines Journalisten nach Gesprächen mit sieben OpenAI-Leuten. Alle Zahlen sind Eigenangaben von OpenAI ohne Methode. |
| OpenAI, "Harness engineering: leveraging Codex in an agent-first world", 2026-02-11 | Nur über Zusammenfassungen Dritter; die Originalseite ließ sich nicht abrufen (HTTP 403). | Die Kernaussagen stimmen in mehreren unabhängigen Zusammenfassungen überein. Einzelheiten (nächtlicher Takt, genaue Dateinamen) sind nicht am Original geprüft. |
| Pragmatic Engineer, Podcast-Seite "Building Codex with Tibo Sottiaux" | Die frei lesbaren Kernpunkte. | Eigenangaben. |
| Vier Sekundärseiten zum Artikel | Vollständig. Keine von ihnen kennt die Abschnitte 4 bis 7; eine sagt das ausdrücklich. | Nur als Gegenprobe benutzt. |

Folge für diese Bewertung: Der Fabrik-Teil (Abschnitt 3) ist der Kern des Artikels und liegt vollständig vor. Zu "Harness-Effizienz" und zum Wandel der Werkzeuge kann nur gesagt werden, dass der Artikel sie behandelt, nicht was er sagt. Wer den Volltext hat, kann die Lücke schließen; die Stellen sind unten mit **[nicht gelesen]** markiert.

Der Text gibt den Artikel in eigenen Worten wieder und zitiert nicht.

## Was der Artikel behauptet

**Verbreitung (Abschnitt 1).** Seit Anfang 2026 läuft bei OpenAI fast alle Arbeit über einen einzigen Harness (Codex und das darauf gebaute ChatGPT Work), auch außerhalb der Entwicklung. Zwei Dinge hätten das getrieben: lang laufende Aufgaben (ein gesetztes Ziel, an dem der Agent tagelang weiterarbeitet und dafür selbst weitere Agenten startet, sodass der Mensch weniger parallel verwalten muss) und rollenspezifische Plugins, mit denen Teams den Agenten an ihre Arbeit anpassen. Fachleute sitzen in den Entwicklungsteams, weil die Entwickler in fremden Fächern keinen Geschmack beisteuern können. Die interne Codex-Fassung ist an fast alle internen Systeme angeschlossen und damit weiter als das Produkt.

**IDE, Pull Requests, Review (Abschnitt 2).** Die Zahl der Pull Requests je Person wächst stark; einzelne Systeme der Build-Test-Deploy-Kette sehen etwa die zehnfache Last binnen eines halben Jahres. Review und Pull Request in ihrer heutigen Form werden in Frage gestellt. Die Antwort sind Reviews durch mehrere Agenten mit je eigenem Blickwinkel und ein Agent, der eine Änderung bis in die Produktion begleitet. Als neuer Engpass wird die Freigabe nativer Mobil-Apps genannt.

**Die Fabrik (Abschnitt 3)**, neun Stationen:

1. Ein Mensch legt das Ergebnis fest. Urteil, Priorität und Geschmack werden wichtiger.
2. Der Agent sammelt Kontext. Die Dokumentation wurde vollständig ins Quell-Repository verlegt. Dazu kommen Git, Chat, Wiki, interne Datenquellen und interne Skills, von denen einige der Agent selbst pflegt.
3. Der Agent setzt um und prüft, ob es funktioniert.
4. Bauen, Testen, Pull Request, CI. Der Agent betreut den Pull Request, bis er grün ist. Auffällige Änderungen gehen zusätzlich durch einen Performance-Vergleich.
5. Review durch mehrere Agenten, jeder auf ein Fachgebiet eingestellt. Änderungen werden nach Risiko eingestuft: hohes Risiko bekommt mehr Reviews oder einen Pflicht-Review durch einen Menschen; Bereiche des Codes können sich dafür entscheiden, dass ein Agent Änderungen mit geringem Risiko selbst freigibt.
6. Nach der Freigabe durch einen Menschen begleitet ein eigener Agent die Änderung durch den Rollout, baut sich dafür ein eigenes Dashboard und beobachtet die Signale.
7. Beobachtung der Produktion.
8. "Perf Factory": Agenten sichten Alarme, entfernen Dubletten, finden echte Latenz-Regressionen, suchen die Ursache und schlagen Korrekturen vor.
9. "Sevbot": sammelt bei einem Vorfall Kontext und schlägt Gegenmaßnahmen vor, führt aber keine aus; ein Mensch ordnet sie an. Bereitschaftsdienst gibt es weiterhin.

**Das Diagramm zur Fabrik** (zuerst übersehen, weil nur der Text ausgewertet wurde; nachgetragen) sagt drei Dinge deutlicher als der Text:

- Die Einstufung nach Risiko ist Teil des Review-Schritts und fällt **je Änderung**, nicht je Code-Bereich. Die Reviewer sind dort benannt: Daten, Infrastruktur, Cloud, Sicherheit, parallel.
- Danach steht eine einzige Weiche: geringes Risiko, ja oder nein. Bei ja geht die Änderung ohne einen Menschen in den begleiteten Rollout. Nur bei nein kommt ein zusätzlicher Review durch einen Engineer dazu. Der Mensch ist der Ausnahmepfad, nicht der Regelpfad. Der Text ist an dieser Stelle vorsichtiger (Bereiche entscheiden sich für die Selbstfreigabe; ein Mensch gibt vor dem Rollout frei); beides zusammen heißt: Die Einstufung fällt je Änderung, die Erlaubnis zur Selbstfreigabe je Bereich.
- Drei Rückkopplungen laufen direkt zurück in den schreibenden Agenten, ohne Umweg über einen Menschen: aus CI, aus dem Review (der Agent korrigiert, bis beides besteht) und aus Perf Factory (Korrekturvorschläge für Performance-Befunde). Von Sevbot führt kein Pfeil zurück.

**Abschnitte 4 bis 7 [nicht gelesen].** Laut Inhaltsangabe: selbst gebaute interne Werkzeuge weichen dem Agenten, der auch beim Debugging den Spezialwerkzeugen vorgezogen wird; die Effizienz des Harness ist in einer solchen Fabrik entscheidend; Spezialisierungen verschwinden, Urteil und Eigeninitiative zählen mehr; Umbauten, die früher als unmöglich galten, gelingen mit ein oder zwei Leuten.

**Der ältere OpenAI-Beitrag "Harness engineering"** (über Zusammenfassungen): ein Team von drei, später sieben Leuten, fünf Monate, rund eine Million Zeilen und etwa 1.500 Pull Requests ohne von Hand geschriebenen Code. Die Mittel: `AGENTS.md` als Inhaltsverzeichnis von rund hundert Zeilen statt als Lexikon; ein `docs/`-Baum als maßgebliche Quelle (Entwurfsdokumente, Ausführungspläne getrennt nach aktiv und abgeschlossen, Produktspezifikationen, eine Liste technischer Schulden, Qualitätsnoten je Bereich); eine feste Schichtenfolge, die eigene Linter und Strukturtests durchsetzen; die Anwendung ist je Worktree startbar und der Agent hat Browser-Steuerung und einen lokalen Beobachtungs-Stack, um sein Ergebnis selbst zu prüfen; wiederkehrende Hintergrundläufe, die Abweichungen von festgeschriebenen Grundsätzen suchen und kleine Aufräum-Pull-Requests öffnen, die meist in unter einer Minute geprüft und automatisch gemergt werden.

## Wie belastbar das ist

- Keine einzige Qualitätszahl: keine Fehler-, Rücknahme- oder Vorfallsrate, kein Vergleich mit der Zeit davor. Gemessen wird Durchsatz. Ob die Fabrik bessere oder nur mehr Software liefert, lässt der Artikel offen.
- OpenAI verkauft den Harness, über den berichtet wird. Die Gesprächspartner sind dessen Leiter.
- Das Token-Budget ist unbegrenzt und der interne Agent ist an alle Systeme angeschlossen. Beides hat kein Leser.
- Die "dunkle Fabrik" gibt es dort nicht, aber der Mensch ist nicht mehr der Regelfall. Menschen sitzen an Station 1 und an 9 und, wenn die Änderung nicht als geringes Risiko eingestuft ist, an 5. Wie oft das eine und wie oft das andere eintritt, sagt der Artikel nicht.
- Der Autor selbst zweifelt daran, dass ein auf "Fachmann für X" eingestellter Agent anders prüft als ein allgemeiner, und führt den Nutzen auf den Kontext zurück, den der Agent bekommt, nicht auf die Rolle.

Übertragbar sind deshalb die Mechanismen, nicht die Zahlen.

## Station für Station gegen ytstack

Grundlage auf der ytstack-Seite ist der technische Spec unter `.ytstack/spec/` (sechs Bereichsdateien, gegen den Code gelesen) und die Formate unter `docs/ux/`.

| Station | ytstack heute | Urteil |
|---|---|---|
| 1 Ergebnis festlegen | `office-hours`, `grill`, `plan-ceo-review`, `plan-milestone` (Ziel und Abnahmekriterien), `slice-milestone`, `plan-task`. Seit M023 und M024 hat auch die Entscheidung des Menschen eine Form: Gates in den Plänen (was, wer entscheidet, wie, wann es verfällt), `questions/Q###` (einmal gestellt), `STANDING.md`. | **Abgedeckt, und genauer als im Artikel.** Der Artikel sagt nur, dass ein Mensch festlegt und freigibt, nicht wie das festgehalten wird. |
| 2 Kontext | Der Kern von ytstack: `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, Pläne und Zusammenfassungen im Repository, per SessionStart-Hook eingespielt. Seit M022 dazu der technische Spec: eine Seite `SPEC.md` (höchstens 80 Zeilen) als Karte, je Bereich eine Datei (höchstens 200 Zeilen) mit dem, was jetzt gilt, nur mit Zeigern auf vorhandene Dokumente. `bin/ytstack-spec drift` meldet Bereiche, deren Pfade sich nach der Beschreibung geändert haben; `summarize-task` schließt keine Aufgabe, deren genannter Bereich nicht nachgezogen wurde. | **Abgedeckt für alles im Repository.** Das ist dieselbe Entscheidung wie bei OpenAI (Dokumentation ins Repository, Karte statt Lexikon), und M022 liefert das Stück, das vorher fehlte: einen Ort für den Ist-Zustand, der mechanisch frisch gehalten wird. **Nicht abgedeckt und nicht Aufgabe von ytstack:** Anschluss an Chat, Wiki, Logs und Metriken. Das leistet der Host über seine Konnektoren; ytstack kennt nur das Feld `tracker:`. |
| 3 Umsetzen und selbst prüfen | `test-driven-development`, `verification-before-completion`, `minimal-code` als ein Arbeitsvertrag, Implementer im eigenen Worktree, Verifier mit frischem Kontext. Seit M023 ist ein Ergebnis eine Prüfung auf einem Commit in einer Umgebung. | **Abgedeckt für Tests und Kommandos.** **Lücke:** Der Agent kann das laufende Produkt nicht ansehen. ytstack sagt nichts dazu, wie eine Anwendung je Worktree gestartet, im Browser bedient und über Logs befragt wird. `RUNTIME.md` existiert, ist aber eine freie Datei ohne Vertrag. |
| 4 CI und Betreuung des Pull Requests | Seit M024: `finish-lane` mit `bin/ytstack-finish-lane` (Reste, Commit, Push, Pull Request, Warten auf den Head, Gates frisch vom Host gelesen, Merge genau am geprüften Commit) und `bin/ytstack-watch`, das nur bei einer Änderung eine Zeile ausgibt. Davor nur `finish-branch` und `ship`. | **Seit M024 abgedeckt, aber ungeprüft:** Die Kette lief nur gegen einen Ersatz für `gh` (Gate G01 in `M024-S02-PLAN.md`). Kein Performance-Vergleich; der ist projektspezifisch. |
| 5 Review und Risiko | `code-review` mit einem Reviewer, der den Diff gegen die Bereichsdateien der geänderten Pfade liest. Seit M023 begrenzt: Runde 1 das Ganze, Runde 2 die Korrektur, ab Runde 3 Diagnose und Frage an den Menschen; die Schwere richtet sich nach der Regel des Projekts. Review-Bots des Hosts zählen in `finish-lane` als Gate. Auf Plan-Ebene gibt es mehrere Blickwinkel (`plan-ceo-review`, `plan-eng-review`, der Agent `architect`). | **Teilweise.** Zwei Dinge fehlen: (a) **keine Einstufung nach Risiko.** ytstack unterscheidet nach Größe (`quick-task` gegen `plan-task`, `granularity`), nicht nach Gefahr, und `merge_by` gilt für das ganze Projekt. (b) **kein zweiter Blickwinkel auf Code**, etwa Sicherheit. Dafür hat ytstack, was dem Artikel fehlt: eine Regel, wann Review aufhört. |
| 6 Rollout begleiten | `ship` (über gstack) bis zum Pull Request. Für Schritte, die nur ein Mensch ausführen darf, `handover-step`: ein gestuftes Skript mit Prüfungen, einer Bestätigung je Änderung und einer Quittung, das der Agent nie selbst startet. | **Lücke, mit einer bewusst anderen Haltung.** Bei OpenAI führt der Agent aus und beobachtet, bei geringem Risiko laut Diagramm ohne einen Menschen davor. In ytstack bereitet der Agent vor und der Mensch führt aus. Was fehlt, ist das Stück danach: beobachten, ob das Ziel-Release wirklich draußen und gesund ist. |
| 7 bis 9 Beobachten, Performance-Rückkopplung, Vorfälle | Nichts. | **Außerhalb des Zuschnitts.** ytstack hat keine Laufzeit und keinen Dienst, der auf Alarme aufwacht (`AGENTS.md`: kein Runtime-Nachbau). Der Grundsatz von Sevbot (vorschlagen, nicht ausführen, der Mensch ordnet an) ist derselbe wie bei `handover-step` und `merge_by: human`. |

Zusammengefasst: ytstack deckt die Entwicklungshälfte der Fabrik ab (Stationen 1 bis 5), die Betriebshälfte (6 bis 9) nicht. Die drei neuen Meilensteine liegen genau auf den Stationen, an denen ytstack vorher am dünnsten war: M022 auf Station 2, M023 auf 3 bis 5, M024 auf 4 und 5.

## Die Querschnittsthemen

**Lange Läufe und Delegation.** OpenAI setzt auf einen Faden, der tagelang läuft und selbst Agenten startet. ytstack setzt auf Dateien, aus denen eine Sitzung nach Verlust ihres Kontexts weiterarbeiten kann: `LANES.md`, die Frontier, Fragen-Dateien, automatische Handoffs vor der Verdichtung, `coordinate` beginnt nie aus einer Gesprächszusammenfassung. `autonomy: loop` läuft innerhalb einer Scheibe ohne Nachfrage und hält an der Scheibengrenze. Das ist dieselbe Richtung mit einer vorsichtigeren Annahme, und für einen Harness, den man nicht selbst baut, ist es die richtige: ytstack kann nicht garantieren, dass ein Faden Tage hält. Der Preis sind mehr Haltepunkte für den Menschen. M023 hat sie verringert (ein Gate hält keine Aufgabe offen, eine gesammelte Frage an der Scheibengrenze).

**Ein Harness gegen mehrere.** Bei OpenAI gibt es einen. ytstack trägt einen Skill-Baum für Claude Code und Codex, ein dritter Host ist geplant (M020). Das kostet Pflege und verhindert, dass ytstack Fähigkeiten eines Hosts voraussetzt, etwa geplante Läufe.

**Rollenspezifische Plugins und eingebettete Fachleute.** Der Artikel beschreibt, was ytstack ist: ein Plugin, das einen allgemeinen Agenten auf eine Arbeit zuschneidet. Die Referenz-Skills (`software-craftsmanship`, `atomic-design`) sind festgeschriebener Geschmack in dem Sinn, den der Artikel meint.

**Skills, die der Agent selbst pflegt.** ytstack: `lane-retro` schlägt aus abgeschlossenen Lanes eine Prüfung vor, die eine Anweisungszeile ersetzt, und setzt nichts selbst um; 21 Eval-Fälle prüfen, ob die Skills auslösen und ihr Ergebnis liefern. Das ist zurückhaltender als bei OpenAI und für ein veröffentlichtes Plugin angemessen.

**Durchsatz und CI-Last.** OpenAI behandelt die zehnfache Last als Infrastrukturaufgabe. M023 setzt an der anderen Seite an und begrenzt die Nachfrage: der Plan nennt Kommando, Zahl der Läufe und Umgebung; der Verifier macht einen unabhängigen Lauf je Commit und beruft sich auf ein früheres Urteil, wenn die Dateien der Aufgabe unverändert sind; ein Test, der nur manchmal fehlschlägt, wird nicht grün gelaufen. Dazu sagt der Artikel im gelesenen Teil nichts; für Projekte ohne unbegrenztes Budget ist es die wichtigere Hälfte.

**Harness-Effizienz [nicht gelesen].** ytstack misst und begrenzt an mehreren Stellen: die SessionStart-Einspielung unter 10.000 Zeichen, Skill-Beschreibungen innerhalb des Listen-Budgets von 1.536 Zeichen, `STATE.md` als Zeiger mit höchstens 12.000 Bytes, der Spec nur mit Zeigern und mit Größengrenzen, Hook-Laufzeiten gemessen, Eval-Kosten festgehalten. Ob das die Fragen trifft, die der Artikel unter diesem Stichwort stellt, ist offen.

**Gegen "Harness engineering" gelesen.**

| Praxis dort | ytstack | Urteil |
|---|---|---|
| `AGENTS.md` als Karte | `SPEC.md` als eine Seite, die Einspielung nennt Dateien statt sie zu wiederholen, `handoff-session` zeigt statt zu kopieren | gleich |
| Pläne als versionierte Artefakte, aktiv und abgeschlossen | `M###`, `S##`, `T##` als Plan und Zusammenfassung, mit Nachweis und Abweichungen | gleich, mit mehr Nachweis |
| Frische der Dokumentation mechanisch | `ytstack-spec lint`, `drift`, `impact`; `ytstack-check` in CI | gleich im Mechanismus; bei ytstack läuft er in der Arbeitsschleife, nicht als wiederkehrender Hintergrundlauf |
| Qualitätsnote je Bereich, Liste technischer Schulden | `status` (planned, partial, implemented) und "Known limits" je Bereich; Folgearbeiten in den Zusammenfassungen | ähnlich, ohne Note und ohne eine gesammelte Liste |
| Architektur und Geschmack über eigene Linter und Strukturtests | `bin/ytstack-check` für ytstacks eigene Verträge; im Projekt die Warnungen des Edit-Hooks (außerhalb des Plans, Schema ohne Migration) und die Vorschläge von `lane-retro` | für ytstack selbst gleich; für Projekte nur der Anstoß, das Gerüst baut das Projekt |
| Anwendung je Worktree startbar, Browser, Beobachtungs-Stack | Worktree je Scheibe, sonst nichts | **Lücke** |
| Wiederkehrendes Aufräumen gegen festgeschriebene Grundsätze | `minimal-code` verhindert vorab; `retro`, `lane-retro` und `reconcile` auf Anstoß | **Lücke im Nachhinein:** kein Lauf, der von selbst kommt |
| Wenige blockierende Merge-Gates, Korrigieren ist billiger als Warten | Jedes Gate frisch gelesen, `merge_by: human` als Vorgabe, kein Grünlaufen | **bewusst entgegengesetzt** |

Zum letzten Punkt: Das ist der Kern der Fabrik und die Stelle, an der ytstack am weitesten von ihr entfernt ist. Bei OpenAI entscheidet die Einstufung der einzelnen Änderung, ob ein Mensch beteiligt wird. In ytstack entscheidet eine Einstellung für das ganze Projekt, und ihre Vorgabe ist der Mensch. Solange das so bleibt, ist jede Änderung, auch ein Tippfehler in der Doku, so teuer wie die Aufmerksamkeit eines Menschen, und der Durchsatz der Agenten endet an dessen Tag. Die Vorsicht hat einen Grund: OpenAI hat hinter der Weiche einen begleiteten Rollout und die Mittel, einen Fehler schnell zurückzunehmen; ein kleines Projekt hat das oft nicht. Der Grund spricht aber für Bedingungen an den Weg ohne Menschen, nicht gegen den Weg.

## Wo ytstack weiter ist, und wo das noch nichts beweist

Weiter als das im Artikel Beschriebene:

- Eine Form für die Entscheidungen des Menschen (Gates, Fragen, stehende Anweisungen, Übergabe mit Quittung).
- Eine Grenze für Prüf- und Review-Arbeit, und zwei getrennte Zahlen am Ende: durch Arbeit geschlossen und angenommen.
- Ein Wortschatz, der geplant, umgesetzt und geprüft auseinanderhält.
- Arbeit, die den Verlust des Kontexts übersteht.

Was das nicht beweist: OpenAI berichtet aus dem Betrieb, ytstack aus Tests. M024 ist nie gegen einen echten Pull-Request-Host gelaufen. Die Evals zeigen, dass zwei von drei Fällen zu begrenzter Arbeit mit den alten Anweisungen scheitern und mit den neuen bestehen, und dass die drei Fälle zu frischen Sitzungen in beiden Ständen bestehen, also keinen messbaren Gewinn auf einem kleinen Projekt zeigen. Eine Qualitätszahl aus echter Nutzung hat ytstack so wenig wie der Artikel.

## Was daraus folgt

Die Reihenfolge ist eine Empfehlung. Nichts davon ist beschlossen oder gebaut; die Punkte 2 bis 6 wären je ein eigener Eintrag in `DECISIONS.md`.

1. **Zuerst M024 im Echtbetrieb erproben (Gate G01).** ytstacks eigene Regel lautet, dass jede Änderung ein beobachtetes Problem lösen muss. Solange `finish-lane` und `coordinate` nicht an einem echten Pull Request gelaufen sind, wäre alles Weitere auf Vermutung gebaut.
2. **Die Risiko-Weiche: ob ein Mensch beteiligt wird, entscheidet die Einstufung der Änderung.** Das ist die übertragbarste Idee des Artikels. Für ytstack hieße das drei Teile:
   - **Die Einstufung je Änderung** fällt im Review, nicht beim Schreiben: Der Reviewer (frischer Kontext, nicht der Autor) nennt Schwere und Reichweite mit Begründung. Darunter liegt ein mechanischer Boden, den kein Urteil unterschreitet: bestimmte Pfade und Arten von Änderung sind nie geringes Risiko (Migrationen, Authentifizierung, Abhängigkeiten, CI- und Deploy-Konfiguration, die Regeln des Projekts selbst, alles über einer Größe).
   - **Konzeptionelle Regeln des Projekts sind Reichweite, kein eigener Mechanismus.** Zwei Fälle, beide enden beim Menschen. Ändert eine Änderung das Dokument, in dem die Regel steht (eine Entscheidung, eine Invariante im Spec, die Anweisungsdatei), greift der mechanische Boden über den Pfad. Verschiebt sie die Regel im Code, ohne das Dokument anzufassen, erkennt das kein Pfad: Dafür liest der Reviewer die Änderung gegen "Invariants and security boundaries" und "Decisions that apply now" der betroffenen Bereiche, und "berührt eine Invariante oder eine geltende Entscheidung" ist ein ausdrückliches Kriterium der Einstufung, das immer zur höchsten Stufe führt. Voraussetzung ist, dass die Regeln dort stehen; was nur in Köpfen oder im Chat steht, kann kein Review schützen.
   - **Die Obergrenze je Bereich** steht im Spec: ein Feld im Kopf der Bereichsdatei, bis zu welcher Einstufung dort ohne Menschen gemergt werden darf. Der Bereich hat schon Pfade und einen Abschnitt "Invariants and security boundaries", und `code-review` gibt dem Reviewer schon die Bereichsdateien der geänderten Pfade. Ein Bereich ohne Angabe verlangt den Menschen.
   - **Der Weg ohne Menschen hat Bedingungen**, die `finish-lane` frisch vom Host liest: alle verlangten Checks grün auf dem geprüften Commit, der Verifier hat bestanden, kein blockierender Befund, Einstufung und Bereich erlauben es. Der Mensch bekommt eine Zeile im Bericht (Prüfung durch Ausnahme). `merge_by` bekäme dafür einen dritten Wert, der die Weiche einschaltet, und der wäre die Vorgabe für ein Projekt, das seine Bereiche eingestuft hat.

   - **Pflicht-Blickwinkel je Art der Änderung.** Neben der Höhe des Risikos zählt die Art: Eine Änderung an der Oberfläche darf den Weg ohne Menschen nur nehmen, wenn im Review auch ein UI/UX-Review gelaufen ist, das gegen die Richtlinien und die Design-Richtlinien des Projekts prüft. Allgemein: Der Spec nennt je Blickwinkel, wann er gilt (Pfade oder Dateiarten), was er liest (die Richtlinien-Dokumente des Projekts, als Zeiger) und welchen Nachweis er braucht. Für die Oberfläche heißt das ein unabhängiges, wirklich visuelles Review: Ein Reviewer mit frischem Kontext, der nicht der Autor ist, startet das Produkt selbst auf dem geprüften Commit, bedient es im Browser und sieht sich das gerenderte Ergebnis an (die betroffenen Ansichten, Zustände und Bildschirmbreiten). Er nimmt seine eigenen Screenshots auf; Bilder, die der Autor mitliefert, zählen nicht, und ein Lesen von Code oder DOM zählt nicht als dieser Blickwinkel. Die Screenshots gehören mit Commit und Umgebung zum Nachweis. Ohne Punkt 3 ist das nicht möglich. Fehlt das Richtlinien-Dokument oder der Nachweis, kann der Blickwinkel nicht laufen, und die Änderung geht an den Menschen. Im installierten gstack gibt es einen Design-Review-Skill, der dafür gewrappt werden könnte.

   Bei höherer Einstufung kommt ein zweiter Blickwinkel dazu (Sicherheit und Grenzen; im installierten gstack gibt es dafür einen Skill, der gewrappt werden könnte) oder der Pflicht-Review durch den Menschen. Der Zweifel des Autors an Rollen-Reviewern wird ernst genommen: Der Blickwinkel entsteht aus dem Ausschnitt des Kontexts, nicht aus einer Rollenbeschreibung.
3. **Ein Vertrag für `RUNTIME.md`: das Produkt je Worktree starten und befragen.** Startkommando, Port-Vergabe, Lebensprobe, Ort der Logs. Der Plan nennt seit M023 schon die Umgebung einer Prüfung; damit könnten Implementer und Verifier das Ergebnis am laufenden Produkt prüfen und nicht nur an Tests. Kleine Textänderung, große Wirkung auf Station 3.
4. **Das Ziel-Release beobachten.** Ein begrenzter Schritt nach dem Merge: Ist der Commit draußen, antwortet das Ziel mit ihm, bleiben die genannten Signale ruhig. Das Muster von `bin/ytstack-watch` trägt; gstack hat dafür einen Skill. Die Ausführung des Rollouts bleibt beim Menschen oder bei der Pipeline des Projekts.
5. **Wiederkehrendes Aufräumen als Rezept, nicht als Skill.** Ein dokumentierter geplanter Lauf, der `ytstack-spec drift`, `ytstack-check` und die Kandidaten von `reconcile` zusammenträgt und eine Frage oder einen Pull Request hinterlässt. Kein neuer Skill, weil nicht jeder Host geplante Läufe hat.

6. **Vorfall und Signal-Eingang als Skills.** Das Vorgehen von Sevbot und Perf Factory ist Skill-Arbeit; ein eigener Stack ist dafür nicht nötig. Den Auslöser liefert der Host (geplante Läufe, je Host ein Rezept), den lesenden Zugriff auf Signale das Projekt (ein Konnektor oder Kommando, eingetragen in `RUNTIME.md` nach Punkt 3). Ein Vorfall-Skill schreibt ein Protokoll und macht jede Gegenmaßnahme zu einem Übergabe-Skript, das der Mensch ausführt. Der Signal-Eingang ist ein geplanter Lauf, der Signale liest, gegen offene Fragen abgleicht und je echtem Befund einen Follow-up anlegt; die Ursachensuche bleibt bei `systematic-debugging`. Harte Regel für beide: nur lesender Zugriff auf die Produktion.

Bewusst nicht übernehmen:

- Den Chat-Teil von Sevbot (im Vorfallskanal mitlesen und antworten). Das ist eine Integration des Hosts.
- Den Weg ohne Menschen ohne die Bedingungen aus Punkt 2, und nie für einen Bereich ohne Einstufung.
- Reviewer, die sich nur durch ihre Rollenbeschreibung unterscheiden.
- Den Pull Request aufgeben. Der Artikel stellt ihn in Frage und beschreibt trotzdem eine Fabrik, in der jede Station an ihm hängt.

## Quellen

- https://newsletter.pragmaticengineer.com/p/openai-software-factory (Abschnitte 1 bis 3)
- https://openai.com/index/harness-engineering/ (nicht abrufbar; gelesen über https://codenote.net/en/posts/harness-engineering-ai-agent-era/ und die Recherche-Angaben auf https://internal-agents.com/agents/openai-software-factory)
- https://newsletter.pragmaticengineer.com/p/building-codex-with-tibo-sottiaux
- Gegenproben zum Artikel: https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/docs/resource-evaluations/2026-09-15-openai-agentic-software-factory.md, https://bayesiansapien.github.io/cere-bro/agentic-systems/2026-09-16-openai-agentic-software-factory/, https://apidog.com/blog/openai-agentic-software-factory/
- ytstack: `.ytstack/spec/SPEC.md` und die sechs Bereichsdateien, `docs/ux/spec-format.md`, `docs/ux/coordinator-format.md`, `docs/concept.md`, `.ytstack/KNOWLEDGE.md` ("Eval runs"), `.ytstack/M024-S02-PLAN.md` (G01)
