# OpenAIs "agentic software factory" gegen ytstack gelesen

Erste Fassung: 2026-11-13, ytstack auf dem Branch `spec-and-bounded-work` (0.5.0 plus M022 Technical Spec, M023 Bounded Work, M024 Coordinator Mode, Pull Request 37), nur Abschnitte 1 bis 3 des Artikels gelesen.
Nachgetragen: 2026-11-16, gegen den vollständigen Artikel und gegen ytstack 0.12.0 auf `main`.

## Quellenlage: was gelesen wurde und was nicht

| Quelle | Gelesen | Belastbarkeit |
|---|---|---|
| Gergely Orosz, "Inside OpenAI's agentic software factory", The Pragmatic Engineer, 2026-09-15 | **Vollständig**, alle sieben Abschnitte und das Fazit, aus einem PDF des bezahlten Artikels, das der Maintainer bereitgestellt hat (28 Seiten). Die erste Fassung kannte nur die frei zugänglichen Abschnitte 1 bis 3. | Bericht eines Journalisten nach Gesprächen mit sieben OpenAI-Leuten. Alle Zahlen sind Eigenangaben von OpenAI ohne Methode. |
| OpenAI, "Harness engineering: leveraging Codex in an agent-first world", 2026-02-11 | Nur über Zusammenfassungen Dritter; die Originalseite ließ sich nicht abrufen (HTTP 403). | Die Kernaussagen stimmen in mehreren unabhängigen Zusammenfassungen überein. Einzelheiten (nächtlicher Takt, genaue Dateinamen) sind nicht am Original geprüft. |
| Pragmatic Engineer, Podcast-Seite "Building Codex with Tibo Sottiaux" | Die frei lesbaren Kernpunkte. | Eigenangaben. |
| Vier Sekundärseiten zum Artikel | Vollständig. Keine von ihnen kennt die Abschnitte 4 bis 7; eine sagt das ausdrücklich. | Nur als Gegenprobe benutzt. |

Der Text gibt den Artikel in eigenen Worten wieder und zitiert nicht.

## Was der Artikel behauptet

**Verbreitung (Abschnitt 1).** Seit Anfang 2026 läuft bei OpenAI fast alle Arbeit über einen einzigen Harness (Codex und das darauf gebaute ChatGPT Work), auch außerhalb der Entwicklung: Finanzen, Recruiting und Recht kamen binnen etwa vier Monaten von fast null auf rund neun Zehntel. Drei Dinge hätten das getrieben: lang laufende Aufgaben (über `/goal` bekommt der Agent ein Ziel und arbeitet daran, oft tagelang, und startet dafür selbst weitere Agenten, sodass der Mensch weniger parallel verwalten muss), rollenspezifische Plugins, mit denen Teams den Agenten an ihre Arbeit anpassen, und Mundpropaganda über Einsatzarten, die viele noch nicht kennen. Fachleute sitzen in den Entwicklungsteams, weil die Entwickler in fremden Fächern keinen Geschmack beisteuern können. Die interne Codex-Fassung ist an fast alle internen Systeme angeschlossen und damit weiter als das Produkt. Die Abhängigkeit ist so groß, dass Kollegen einen Ausfall des Harness oft vor dem Alarm melden.

**IDE, Pull Requests, Review (Abschnitt 2).** Die IDE-Nutzung sinkt seit Januar. Die Zahl der Pull Requests je Person wächst stark; einzelne Systeme der Build-Test-Deploy-Kette sehen etwa die zehnfache Last binnen eines halben Jahres. Review und Pull Request in ihrer heutigen Form werden in Frage gestellt. Die Antwort sind Reviews durch mehrere Agenten mit je eigenem Blickwinkel und ein Agent, der eine Änderung bis in die Produktion begleitet. Als neuer Engpass wird die Freigabe nativer Mobil-Apps genannt.

**Die Fabrik (Abschnitt 3)**, neun Stationen:

1. Ein Mensch legt das Ergebnis fest. Urteil, Priorität und Geschmack werden wichtiger; Engineers werden eher Produktmanager.
2. Der Agent sammelt Kontext. Die Dokumentation wurde vollständig ins Quell-Repository verlegt. Dazu kommen Git, Chat, Wiki, interne Datenquellen und interne Skills, von denen einige der Agent selbst pflegt.
3. Der Agent setzt um und prüft, ob es funktioniert.
4. Bauen, Testen, Pull Request, CI. Der Agent betreut den Pull Request, bis er grün ist. Auffällige Änderungen schickt er zusätzlich durch einen Performance-Vergleich (A/B gegen synthetische Last).
5. Review durch mehrere Agenten, jeder auf ein Fachgebiet eingestellt. Änderungen werden nach Risiko eingestuft: hohes Risiko bekommt mehr Reviews oder einen Pflicht-Review durch einen Menschen; Bereiche des Codes können sich dafür entscheiden, dass ein Agent Änderungen mit geringem Risiko selbst freigibt. Die Einstufung entscheidet auch, ob zusätzliche Compliance-Prüfung von einem Agenten oder einem Menschen kommt. Review-Kommentare arbeitet der schreibende Agent ab wie CI-Fehler.
6. Nach der Freigabe durch einen Menschen begleitet ein eigener Agent die Änderung durch den Rollout, auch hinter einem Feature-Flag: Er findet das Flag, versteht die Änderung, legt selbst fest, welche Signale Erfolg und Misserfolg anzeigen, baut sich dafür ein eigenes Dashboard und beobachtet. Ziel ist ein autonomer SRE je Änderung.
7. Beobachtung der Produktion, über die Dashboards je Änderung und den internen Observability-Stack.
8. "Perf Factory": Agenten sichten Alarme, entfernen Dubletten, finden echte Latenz-Regressionen, suchen die Ursache und schlagen Korrekturen vor.
9. "Sevbot": sammelt bei einem Vorfall Kontext und schlägt Gegenmaßnahmen vor, führt aber keine aus; ein Mensch ordnet sie an. Bereitschaftsdienst gibt es weiterhin. Ziel ist, dass Sevbot Routine-Ausfälle selbst behebt und Menschen das erst danach prüfen.

**Das Diagramm zur Fabrik** (zuerst übersehen, weil nur der Text ausgewertet wurde; nachgetragen) sagt drei Dinge deutlicher als der Text:

- Die Einstufung nach Risiko ist Teil des Review-Schritts und fällt **je Änderung**, nicht je Code-Bereich. Die Reviewer sind dort benannt: Daten, Infrastruktur, Cloud, Sicherheit, parallel.
- Danach steht eine einzige Weiche: geringes Risiko, ja oder nein. Bei ja geht die Änderung ohne einen Menschen in den begleiteten Rollout. Nur bei nein kommt ein zusätzlicher Review durch einen Engineer dazu. Der Mensch ist der Ausnahmepfad, nicht der Regelpfad. Der Text ist an dieser Stelle vorsichtiger (Bereiche entscheiden sich für die Selbstfreigabe; ein Mensch gibt vor dem Rollout frei); beides zusammen heißt: Die Einstufung fällt je Änderung, die Erlaubnis zur Selbstfreigabe je Bereich. Der volle Text löst den Widerspruch nicht auf.
- Drei Rückkopplungen laufen direkt zurück in den schreibenden Agenten, ohne Umweg über einen Menschen: aus CI, aus dem Review (der Agent korrigiert, bis beides besteht) und aus Perf Factory (Korrekturvorschläge für Performance-Befunde). Von Sevbot führt kein Pfeil zurück.

**Werkzeuge und Praktiken (Abschnitt 4).** Das Codex-Team misst seinen Harness über Daumen hoch oder runter im Werkzeug und über die Verteilung der Zeit je Antwort (p90 bis p99). Selbst gebaute Dashboards und Log-Werkzeuge verschwinden: Verteilt wird nicht mehr das Dashboard, sondern ein Skill, der es bei Bedarf baut. Beim Debugging und in Ausfällen fragt man zuerst Codex, das über die angeschlossenen Datenquellen selbst Abfragen baut. Unter **Harness-Effizienz** nennen zwei Codex-Engineers drei Maße: Tokens je Aufgabe, Erfolgsquote, Latenz. Und drei Hebel: bessere Werkzeuge (weniger Rundreisen je "Turn"), sorgfältig zusammengestellter Kontext (er hält den KV-Cache des Modells warm, und viele geladene Plugins oder Anweisungen verleiten das Modell dazu, Tokens und Werkzeugaufrufe auf deren Erkundung zu verwenden; was zur Aufgabe passt, auszuwählen, senkt das) und Rückfluss guter Harness-Taktiken ins Training. Ein möglichst warmer KV-Cache gilt als der größte Einzelgewinn.

**Infrastruktur (Abschnitt 5).** Für ytstack nur am Rand: zehnfache Last alle neun bis achtzehn Monate, erst kaufen und später selbst bauen, Anfragen je nach Latenz-Empfindlichkeit nah am Nutzer oder nach freier Kapazität verteilen, Rechenkapazität erst binden, wenn sie wirklich bereitsteht, und als Grundsatz keine stille Verschlechterung: Ein Dienst läuft wie erwartet oder ist ausgefallen.

**API (Abschnitt 6).** Der Engpass ist oft die CPU, nicht die GPU: Tokenisierung und Prüfung der Anfrage wachsen mit der Kontextlänge, und ein agentischer Lauf mit vierzig und mehr Werkzeugaufrufen hat den ganzen Verlauf früher bei jedem Aufruf neu tokenisiert. Über eine stehende WebSocket-Verbindung wird jetzt nur noch das Neue tokenisiert; der Median der Latenz fiel nach OpenAIs Angabe um etwa 30 Prozent. Ausgerollt wird absichtlich langsam (Canary, dann Wellen mit Beobachtung dazwischen). Die API-Schicht wird von zwei Engineers mit Codex von Python nach Rust umgeschrieben.

**Der Beruf (Abschnitt 7).** Spezialisierungen (Frontend, Backend, Mobil) verschwinden. Interne Support-Kanäle der Infrastruktur verstummen, weil man Codex fragt. Was zählt: Urteil, Priorisierung, Eigeninitiative (unaufgefordert parallel mit Agenten arbeiten), Geschmack. Es entsteht eine neue Ebene oberhalb des Codes: die Umgebung bauen, in der Agenten arbeiten (welche Werkzeuge, wie Kontext strukturiert wird, welche Skills und Plugins). Der Autor bezweifelt, dass das außerhalb eines Harness-Herstellers überall so kommt. Für Nicht-Entwickler sind Dokumente, Folien und Tabellen das, was für Entwickler der Pull Request ist. Umbauten, die früher ein großes Team brauchten, gelingen mit ein oder zwei Leuten.

**Fazit des Autors.** Am stärksten beeindruckt ihn die Fabrik und der Agent, der den Rollout selbst begleitet. Er warnt aber davor, das blind zu übernehmen: OpenAI hat kein Token-Budget und verkauft Tokens. Fallende Preise könnten das für andere erschwinglich machen.

**Der ältere OpenAI-Beitrag "Harness engineering"** (über Zusammenfassungen): ein Team von drei, später sieben Leuten, fünf Monate, rund eine Million Zeilen und etwa 1.500 Pull Requests ohne von Hand geschriebenen Code. Die Mittel: `AGENTS.md` als Inhaltsverzeichnis von rund hundert Zeilen statt als Lexikon; ein `docs/`-Baum als maßgebliche Quelle (Entwurfsdokumente, Ausführungspläne getrennt nach aktiv und abgeschlossen, Produktspezifikationen, eine Liste technischer Schulden, Qualitätsnoten je Bereich); eine feste Schichtenfolge, die eigene Linter und Strukturtests durchsetzen; die Anwendung ist je Worktree startbar und der Agent hat Browser-Steuerung und einen lokalen Beobachtungs-Stack, um sein Ergebnis selbst zu prüfen; wiederkehrende Hintergrundläufe, die Abweichungen von festgeschriebenen Grundsätzen suchen und kleine Aufräum-Pull-Requests öffnen, die meist in unter einer Minute geprüft und automatisch gemergt werden.

## Wie belastbar das ist

- Keine Qualitätszahl für die Fabrik: keine Fehler-, Rücknahme- oder Vorfallsrate, kein Vergleich mit der Zeit davor. Gemessen wird Durchsatz. Die einzigen harten Zahlen im ganzen Artikel betreffen Infrastruktur (Latenz der API, Zeilen der Rust-Migration) und die Nutzung des Harness. Ob die Fabrik bessere oder nur mehr Software liefert, lässt der Artikel offen.
- OpenAI verkauft den Harness, über den berichtet wird. Die Gesprächspartner sind dessen Leiter. Der Autor sagt das in Abschnitt 7 selbst.
- Das Token-Budget ist unbegrenzt und der interne Agent ist an alle Systeme angeschlossen. Beides hat kein Leser, und der Autor rät aus genau diesem Grund vom blinden Nachbau ab.
- Die "dunkle Fabrik" gibt es dort nicht, aber der Mensch ist nicht mehr der Regelfall. Menschen sitzen an Station 1 und an 9 und, wenn die Änderung nicht als geringes Risiko eingestuft ist, an 5. Wie oft das eine und wie oft das andere eintritt, sagt der Artikel nicht.
- Der Autor war skeptisch, ob ein auf "Fachmann für X" eingestellter Agent anders prüft als ein allgemeiner. Er hält es dann doch für wahrscheinlich, führt den Nutzen aber auf den Kontext zurück, den der Agent bekommt, und darauf, dass er sich mit seinem begrenzten Kontextfenster auf ein Fach beschränkt, nicht auf die Rolle.

Übertragbar sind deshalb die Mechanismen, nicht die Zahlen.

## Station für Station gegen ytstack 0.12.0

Grundlage auf der ytstack-Seite: der technische Spec unter `.ytstack/spec/`, die Formate unter `docs/ux/` und `CHANGELOG.md` 0.7.0 bis 0.12.0. Die Empfehlungen der ersten Fassung sind seitdem als M025 bis M027 (0.7.0) und in den Folge-Releases gebaut worden; die Tabelle zeigt den Stand, nicht die Empfehlung.

| Station | ytstack 0.12.0 | Urteil |
|---|---|---|
| 1 Ergebnis festlegen | `office-hours`, `grill`, `plan-ceo-review`, `plan-milestone` (Ziel und Abnahmekriterien), `slice-milestone`, `plan-task`. Die Entscheidung des Menschen hat eine Form: Gates, `questions/` mit `class: escalation\|info` (0.12.0), stehende Anweisungen als eine Datei je Eintrag unter `.ytstack/standing/` mit `until` und `check:` (0.10.0, 0.12.0), und `escalate:` in `PREFERENCES.md`, das festlegt, was überhaupt zum Menschen geht. | **Abgedeckt, und genauer als im Artikel.** Der Artikel sagt nur, dass ein Mensch festlegt; ytstack sagt auch, was er nicht mehr entscheiden muss. |
| 2 Kontext | `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md` als Zeiger, der technische Spec (`SPEC.md` als Karte, je Bereich eine Datei), per SessionStart eingespielt; stehende Einträge erreichen jede Rolle und jeden Brief (0.12.0). `ytstack-spec drift` und `impact` halten den Spec frisch, `finish-lane route` prüft das Spec-Delta vor einem Merge ohne Menschen. | **Abgedeckt für alles im Repository**, mit derselben Entscheidung wie bei OpenAI (Dokumentation ins Repository, Karte statt Lexikon). **Nicht Aufgabe von ytstack:** Chat, Wiki, Datenbanken; das leisten die Konnektoren des Hosts. Neu sichtbar: der Kontext hat ein Budget, und das ist voll (#95). |
| 3 Umsetzen und selbst prüfen | Arbeitsvertrag (`test-driven-development`, `verification-before-completion`, `minimal-code`), Implementer im Worktree, Verifier mit frischem Kontext. Seit M025-S01 hat `RUNTIME.md` einen Vertrag ("Run", "Release", "Signals"); `ytstack-runtime up` startet das Produkt je Worktree auf eigenem Port, Verifier und Implementer prüfen am laufenden Produkt, wo der Plan es nennt. | **Abgedeckt.** Die Lücke der ersten Fassung ist geschlossen. |
| 4 CI und Betreuung des Pull Requests | `finish-lane` mit `ytstack-finish-lane` (Merge am geprüften Commit, Obergrenze offener PRs, harter Riegel gegen Schließen), PR-Watch (0.8.0) für rote CI, offene Bot-Threads und Konflikte, seit 0.12.0 mit `STALL 1`/`STALL 2` nach je 15 Minuten ohne neuen Head und Fokus-PRs, die jede Runde gelesen werden. | **Abgedeckt und im Feld gelaufen:** Koordinator-Läufe mit mehreren hundert PRs gegen GitHub (#54, #79). Gate G01 ist trotzdem formal offen (`Q001`). Kein Performance-Vergleich; der ist projektspezifisch. |
| 5 Review und Risiko | Risiko-Weiche je Änderung (M025): `ytstack-risk floor` aus dem Diff, `code-review` mit `Risk`, `Severity`, `Reach`, `Invariants touched`, Obergrenze `auto_merge` je Bereich, Pflicht-Linsen aus `REVIEW.md` (darunter `visual-review` mit eigenen Screenshots), `ytstack-risk route` sagt `unattended` oder `person`; `merge_by: risk` ist Vorgabe. `review-lessons` lernt aus Bot-Befunden, die eigene Reviewer verpasst haben; `## Checks` in `REVIEW.md` listet die maschinellen Prüfungen. | **Abgedeckt, im Mechanismus näher am Diagramm als am Text.** Eine Linse ist über die Dokumente definiert, die sie liest, nicht über eine Rolle; das ist genau der Punkt, auf den der Autor den Nutzen zurückführt. **Ungeprüft:** Kein Merge ohne Menschen ist bisher gegen einen echten Host gelaufen (README, "What has run where"). |
| 6 Rollout begleiten | `ytstack-watch release --commit` (M026) wartet, bis das Ziel den Commit ausliefert, fragt die Gesundheit über die Settle-Zeit und schreibt eine Quittung; es deployt nichts und nimmt nichts zurück. Schritte nur für Menschen über `handover-step`. | **Teilweise, mit bewusst anderer Haltung.** Bei OpenAI wählt der Agent die Signale je Änderung und baut sein Dashboard; in ytstack stehen sie fest in `RUNTIME.md` "Signals". Gegen ein echtes Ziel nie gelaufen. |
| 7 bis 9 Beobachten, Performance-Rückkopplung, Vorfälle | `signal-intake` liest die Signal-Quellen nur lesend und legt Befunde einmal an (Wiederholung erhöht den Zähler, Sichtung eines behobenen ist Regression); `incident` führt das Protokoll und macht jede Gegenmaßnahme zum Übergabe-Skript; `lesson` (0.11.0) beendet jeden Vorfall mit einer Lehre, die möglichst eine Maschine prüft. Auslöser ist ein geplanter Lauf (`docs/recipes/recurring-upkeep.md`), kein Alarm. | **Abgedeckt als Skill-Arbeit, nicht als Dienst.** Sevbots Grundsatz (vorschlagen, Mensch ordnet an) ist derselbe. Weiter als im Artikel: Von Sevbot führt kein Pfeil zurück, von `incident` führt einer über `lesson` in Tests und Guards. |

Zusammengefasst: Die erste Fassung fand die Entwicklungshälfte (1 bis 5) abgedeckt und die Betriebshälfte (6 bis 9) leer. Heute hat jede Station ein Werkzeug. Was fehlt, ist nicht mehr Mechanik, sondern Nachweis im Feld für die beiden Stellen, an denen der Mensch wegfällt: der Merge ohne Menschen und die Release-Beobachtung.

## Die Querschnittsthemen

**Lange Läufe und Delegation.** Der volle Text bestätigt: Der Treiber ist `/goal`, ein Ziel, an dem der Faden tagelang arbeitet. ytstack setzt weiter auf Dateien, aus denen eine Sitzung nach Kontextverlust weiterarbeitet, und hat seitdem viel an den Faden gehängt: Pflicht-Checkliste im Koordinator-Modus, Hinweise der Hooks bei Abweichung, Rotation nach Verdichtung, Liveness je Lane (`ytstack-frontier check`, `stale:`). Was fehlt, ist die Klammer, die den Faden am Ziel hält (#99, unten).

**Ein Harness gegen mehrere.** Bei OpenAI gibt es einen und kein Budget. ytstack trägt seit 0.9.0 drei Hosts (Claude Code, Codex, Kimi Code). Das kostet Pflege, und es erzeugt ein Problem, das der Artikel gar nicht haben kann: Welche Maschine bekommt welche Lane, und was passiert an einem Limit (#80, unten).

**Rollenspezifische Plugins und die neue Ebene.** Der Artikel beschreibt, was ytstack ist: ein Plugin, das einen allgemeinen Agenten auf eine Arbeit zuschneidet, und damit Arbeit auf der Ebene, die Abschnitt 7 neu nennt (Werkzeuge, Kontextstruktur, Skills für den Harness). Dass dort Dashboards durch Skills ersetzt werden, die sie bei Bedarf bauen, ist dieselbe Richtung wie ytstacks Regel, eine Lehre als Prüfung statt als Prosa abzulegen.

**Skills, die der Agent selbst pflegt.** `lane-retro`, `lesson`, `review-lessons` und der Upstream-Kanal (`upstream_feedback: suggest|file|off`, 0.11.0) schlagen Änderungen an Prüfungen und an ytstack selbst vor; nichts davon ändert eine Anweisungsdatei selbst. Zurückhaltender als bei OpenAI und für ein veröffentlichtes Plugin angemessen.

**Durchsatz und CI-Last.** OpenAI behandelt die zehnfache Last als Infrastrukturaufgabe (Abschnitte 5 und 6). ytstack begrenzt die Nachfrage: Prüfläufe je Commit statt je Kontext, eine Obergrenze offener PRs, eine Reserve im GitHub-Kontingent für die PR-Watch. Der Feldlauf aus #79 zeigt die eigene Last: 176 von über 500 PRs waren Buchhaltung.

**Harness-Effizienz.** Jetzt gelesen, siehe Abschnitt 4 oben. ytstack misst bisher nur eine der drei Größen und die nur indirekt: Es begrenzt Zeichen (SessionStart unter 10.000, Skill-Beschreibungen im Listen-Budget, `STATE.md` unter 12.000 Bytes, Spec mit Größengrenzen). Erfolgsquote misst es über die Evals, Latenz gar nicht. Den Hebel "Kontext auswählen statt alles laden" hat ytstack am Spec umgesetzt (Reviewer lesen nur die Bereichsdateien der geänderten Pfade), an der Einspielung selbst nicht (#95).

**Gegen "Harness engineering" gelesen.**

| Praxis dort | ytstack 0.12.0 | Urteil |
|---|---|---|
| `AGENTS.md` als Karte | `SPEC.md` als eine Seite, die Einspielung nennt Dateien statt sie zu wiederholen, `handoff-session` zeigt statt zu kopieren | gleich |
| Pläne als versionierte Artefakte, aktiv und abgeschlossen | `M###`, `S##`, `T##` als Plan und Zusammenfassung, mit Nachweis und Abweichungen; Artefakte folgen dem Verzeichnis ihres Meilensteins (0.12.0) | gleich, mit mehr Nachweis |
| Frische der Dokumentation mechanisch | `ytstack-spec lint`, `drift`, `impact`; `ytstack-check` in CI; Spec-Delta vor dem Merge ohne Menschen | gleich |
| Qualitätsnote je Bereich, Liste technischer Schulden | `status` und "Known limits" je Bereich; Folgearbeiten in den Zusammenfassungen; Befunde und Lehren unter `.ytstack/signals/` | ähnlich, ohne Note |
| Architektur und Geschmack über eigene Linter und Strukturtests | `bin/ytstack-check`; im Projekt der Risiko-Boden, `## Checks` in `REVIEW.md`, Lehren als Guard über `lesson` | für Projekte jetzt ein Weg, das Gerüst baut weiter das Projekt |
| Anwendung je Worktree startbar, Browser, Beobachtungs-Stack | `ytstack-runtime up` je Worktree, `visual-review` im Browser, "Signals" in `RUNTIME.md` | gleich im Format; im Feld kaum gelaufen |
| Wiederkehrendes Aufräumen gegen festgeschriebene Grundsätze | `ytstack-upkeep` als geplanter Lauf nach Rezept, hinterlässt höchstens eine Frage | gleich im Ziel; öffnet keine Aufräum-PRs |
| Wenige blockierende Merge-Gates, Korrigieren ist billiger als Warten | `merge_by: risk` als Vorgabe; ohne `auto_merge` geht weiter alles an den Menschen | **angenähert**, die Vorsicht sitzt jetzt in den Bedingungen, nicht in der Vorgabe |

Der letzte Punkt war in der ersten Fassung der weiteste Abstand zur Fabrik. M025 hat ihn so geschlossen, wie es die Notiz vorgeschlagen hatte: Einstufung je Änderung, Obergrenze je Bereich, Weg ohne Menschen nur unter Bedingungen.

## Wo ytstack weiter ist, und wo das noch nichts beweist

Weiter als das im Artikel Beschriebene:

- Eine Form für die Entscheidungen des Menschen und eine Regel, welche ihn überhaupt erreichen (`escalate:`).
- Eine Grenze für Prüf- und Review-Arbeit, und zwei getrennte Zahlen am Ende: durch Arbeit geschlossen und angenommen.
- Ein Rückpfeil vom Vorfall in die Prüfungen (`lesson`) und vom verpassten Bot-Befund in die Reviewer (`review-lessons`).
- Arbeit, die den Verlust des Kontexts übersteht.

Was das nicht beweist: OpenAI berichtet aus dem Betrieb, ytstack aus Tests und aus einigen Koordinator-Läufen. Gegen einen echten Host gelaufen sind `finish-lane`, die PR-Watch und `ytstack-review-escapes`; nicht gelaufen sind ein Merge ohne Menschen und `ytstack-watch release` (README, "What has run where"). Eine Qualitätszahl aus echter Nutzung hat ytstack so wenig wie der Artikel.

## Was der volle Artikel für die offenen Issues heißt

- **#79, der Host als Ledger (entschieden 2026-11-16).** Der volle Text stützt die Entscheidung: Bei OpenAI ist der Zustand einer Änderung ihr Pull Request und der Faden des Agenten, der ihn betreut; eine Buchhaltung im Repository kommt nicht vor. Neu aus Abschnitt 4: Auch Dashboards werden dort nicht dauerhaft gepflegt, sondern bei Bedarf gebaut. Für `LANES.md` heißt das dasselbe wie Punkt 4 der Entscheidung: ein Schnappschuss auf Anfrage, kein gepflegtes Artefakt.
- **#99, Ziel-Modus.** Bestätigt als wichtigster Treiber der Verbreitung: ein Ziel, ein Faden über Tage, Unteragenten statt paralleler Menschenarbeit. Der Artikel sagt nichts darüber, wann `/goal` aufhört; ytstacks Vorschlag (Stop-Hook mit Abnahmekriterien, Ausnahmen für offene Frage, Blocker, laufende Hintergrundarbeit, harte Grenze) ist genau das fehlende Stück. Wichtig nach #79: Wenn der Zustand mit dem Faden lebt, braucht der Faden die Klammer. Punkt 5 des Issues (auf Codex dessen eigenes `/goal` nutzen) passt zum Artikel.
- **#95, Einspielungsbudget.** Abschnitt 4 gibt dem Issue seine Begründung. Viele geladene Anweisungen kosten nicht nur Platz, sie lenken das Modell auf ihre Erkundung; Vorschlag 1 (`using-ytstack` teilen, Referenzteil nur bei Bedarf lesen) und Vorschlag 2 (im Koordinator-Modus ersetzt die Checkliste die Skill-Liste) sind die Auswahl nach Aufgabe, die das Codex-Team beschreibt. Zwei Ergänzungen: (a) KV-Cache: Die Einspielung beim Start bildet den Anfang des Kontexts. Was sich darin von Sitzung zu Sitzung oder nach jeder Verdichtung ändert (Zeitstempel, Zähler, STALL-Zeilen), gehört ans Ende oder in die Hinweise pro Prompt, damit der stabile Teil vorn gleich bleibt. Ob der Host das als Präfix cacht, ist zu prüfen, nicht anzunehmen. (b) Messen: Vorschlag 3 misst Zeichen; die drei Maße des Artikels (Tokens, Erfolgsquote, Latenz) ließen sich über die Evals erheben, die ytstack schon hat.
- **#80, Engine-Routing.** Der Artikel hilft hier am wenigsten: OpenAI hat einen Harness und kein Budget, der Autor warnt genau deshalb vor dem Nachbau. Übertragbar sind zwei Grundsätze aus Abschnitt 5: Arbeit nach ihrer Empfindlichkeit verteilen (interaktiv nah, lang laufend dorthin, wo Kapazität frei ist) entspricht einer Vorliebe je Lane-Art in `engines:`; und Kapazität erst beim Dispatch binden, nicht im Plan. Dazu der Grundsatz "keine stille Verschlechterung": Trifft eine Engine ihr Limit, sagt der Dispatcher das und nennt die Reset-Zeit, statt still auf eine schwächere auszuweichen.

## Quellen

- https://newsletter.pragmaticengineer.com/p/openai-software-factory (vollständig, über das PDF des Maintainers)
- https://openai.com/index/harness-engineering/ (nicht abrufbar; gelesen über https://codenote.net/en/posts/harness-engineering-ai-agent-era/ und die Recherche-Angaben auf https://internal-agents.com/agents/openai-software-factory)
- https://newsletter.pragmaticengineer.com/p/building-codex-with-tibo-sottiaux
- Gegenproben zum Artikel: https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/docs/resource-evaluations/2026-09-15-openai-agentic-software-factory.md, https://bayesiansapien.github.io/cere-bro/agentic-systems/2026-09-16-openai-agentic-software-factory/, https://apidog.com/blog/openai-agentic-software-factory/
- ytstack: `CHANGELOG.md` 0.7.0 bis 0.12.0, `README.md` ("What has run where"), `.ytstack/spec/SPEC.md` und die Bereichsdateien, `docs/ux/review-policy-format.md`, `docs/ux/runtime-format.md`, `docs/ux/coordinator-format.md`, `docs/recipes/recurring-upkeep.md`, `.ytstack/STATE.md` (`Q001`, Gate G01), Issues #54, #79, #80, #95, #99
