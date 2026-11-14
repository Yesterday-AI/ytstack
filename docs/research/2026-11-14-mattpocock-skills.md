# mattpocock/skills gegen ytstack gelesen

Stand: 2026-11-14. ytstack auf dem Branch `risk-gate` (Pull Request 38, Commit `8d11a67`: alles aus `main` plus M025 bis M027). Upstream gelesen bei `mattpocock/skills@5863806` (2026-11-12).

## 1. Quellenlage

| Quelle | Gelesen | Belastbarkeit |
|---|---|---|
| `mattpocock/skills@5863806dd4e15c63174bee4e7515a4256792ecfa` | Alle 27 `SKILL.md` aus `skills/engineering/` und `skills/productivity/`, dazu `ask-matt/PHASE-BOUNDARIES.md`, `triage/AGENT-BRIEF.md`, `README.md`, `SCOPE.md`, `AGENTS.md`, `GLOSSARY.md`, `CHANGELOG.md` (1.3.0 bis 1.3.2), alle neun Dateien unter `.out-of-scope/`, die Bucket-READMEs. Aus `skills/in-progress/`: `software-factory` (mit `EXAMPLE-TASKS.md`), `chief-of-staff`, `loop-me`, `claude-handoff`, `setup-ts-deep-modules`. | Primärquelle, per `gh api` am Commit geholt. |
| Nicht gelesen | Die Begleitdateien `tdd/tests.md`, `tdd/mocking.md`, `codebase-design/DEEPENING.md` und `DESIGN-IT-TWICE.md`, `prototype/LOGIC.md` und `UI.md`, `improve-codebase-architecture/HTML-REPORT.md`, `wizard/template.sh`, die Vorlagen von `setup-matt-pocock-skills`, `teach/*-FORMAT.md`; die Docs-Seiten unter `docs/`; `.agents/`; die Schreib-Skills in `in-progress/` (`writing-*`) und `misc/` (eingefroren). | Urteile über diese Skills stützen sich auf deren `SKILL.md`. |
| ytstack | `README.md`, `docs/concept.md` (3.1, 3.7, 4.1), `.ytstack/spec/SPEC.md` und `skills.md`, `.ytstack/DECISIONS.md` ab 2026-11-07, `.ytstack/ROADMAP.md` (M019), `.ytstack/KNOWLEDGE.md` ("Eval runs"), `NOTICE`, `bin/ytstack-check`, `evals/README.md`, die Frontmatter aller 38 Skills, gezielt die Rümpfe von `code-review`, `grill`, `coordinate`, `lane-retro`, `slice-milestone`, `handoff-session`, `ship/references/pr-body.md`. | Gegen die Dateien geprüft, nicht gegen frühere Notizen. Kein Skill wurde für diese Notiz ausgeführt. |
| Frühere Notiz | `docs/research/2026-11-07-notes/developer-skills-landscape.md`, besonders Kernfrage 1 und die zehn Empfehlungen. | Nur als Liste der Wünsche benutzt; der Status unten ist an ytstack nachgeprüft. |

**Korrektur einer Annahme.** Die Skills `ask-matt`, `codebase-design`, `domain-modeling`, `implement`, `implement-spec`, `to-spec`, `to-tickets`, `wayfinder`, `wizard`, `research`, `triage`, `teach`, `to-questionnaire` und `wait-what` sind nicht seit dem 2026-11-07 neu: Die Landscape-Notiz führt alle schon auf, und das Plugin hat damals wie heute 27 Skills (`.claude-plugin/plugin.json`, Version 1.3.2 vom 2026-10-29). Seit dem Stand, den `NOTICE` nennt (`4ae2317`, 2026-10-31), gibt es upstream genau zwei Commits; beide ändern nur `in-progress/software-factory` (Wortwahl "task" statt "job", die explore-Aufgabe hinterlässt Befunde). Sterne am 2026-11-14: 324.071.

Diese Notiz gibt Upstream in eigenen Worten wieder und zitiert keine Skill-Texte.

## 2. Was bisher in ytstack eingeflossen ist

### 2.1 Die zehn Empfehlungen vom 2026-11-07

| Nr | Empfehlung (kurz) | Status | Beleg in ytstack |
|---|---|---|---|
| 1 | Beschreibungen nur als Auslöser, keine Zusammenfassung des Ablaufs | **umgesetzt**, mit Rest | M019-S01 (`.ytstack/ROADMAP.md`, Zeile 39); `bin/ytstack-check` Zeilen 155 bis 165 (`DESC_PROCEDURE_PHRASES`, mit Verweis auf Pocock) und die 1.024-Zeichen-Grenze. "Thin ytstack wrapper" steht in keiner Beschreibung mehr. Rest: sechs Wrapper nennen in der Beschreibung noch ihre Herkunft ("through the vendored superpowers ... procedure"): `code-review`, `finish-branch`, `grill`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`. |
| 2 | Aufruf-Achse (`disable-model-invocation` / `user-invocable`) statt `tier` | **teilweise** | `tier` und `version` liegen unter `metadata` (`docs/ux/skill-structure.md`, Zeile 48). `user-invocable: false` tragen nur die zwei Direktiven (`using-ytstack`, `minimal-code`; `.ytstack/spec/skills.md`, Skill-Klassen). `disable-model-invocation` hat kein einziger Skill. M019 hatte das als Ziel; die "Shipped"-Liste nennt es nicht, und kein DECISIONS-Eintrag begründet den Verzicht. Der Grund steht nur indirekt in `docs/concept.md` 4.1: der Agent wählt die Skills, Slash-Befehle sind der Notausgang. |
| 3 | Prozedur-Skills Richtung 100 Zeilen schrumpfen | **nicht** | Gemessen am 2026-11-14: 38 Skills, 10.424 Zeilen in `skills/*/SKILL.md` (Mittel 274; ohne `references/` und ohne den zur Laufzeit eingelesenen superpowers-Text). Am 2026-11-07 waren es laut Notiz 21 Skills und rund 3.500 Zeilen. Sieben Skills liegen über 450 Zeilen (`adopt-brownfield` 679, `init-project` 606, `retro` 530, `plan-ceo-review` 524, `plan-eng-review` 501, `office-hours` 475, `document-release` 452). Der Resolver-Block steht weiter in jedem Preamble, ruft aber Funktionen aus `hooks/lib/git-ctx.sh`. |
| 4 | Fünf fehlende Skills | **teilweise** | `code-review`: vorhanden, aber anders geschnitten (superpowers-Wrapper, ein Reviewer, dazu Prüfung gegen die Bereichsdateien, Runden-Grenze, Risikoklasse; M023, M025). `pr`: nur als Teil von `ship` (`skills/ship/references/pr-body.md` mit "Blast radius" und Testzahlen vorher/nachher, ohne Aussage zur Umkehrbarkeit); `finish-lane` hat kein eigenes Format für den Body. `retro`: zweifach, `retro` (aus gstack, je Meilenstein) und `lane-retro` (Prüfung statt Prosa, in `NOTICE` Pocock zugeschrieben). `research`: **fehlt**. `grilling`: `grill` umhüllt superpowers `brainstorming` mit AskUserQuestion, nicht das Runden-Interview. |
| 5 | Minimal-Code-Wächter | **umgesetzt** | `skills/minimal-code/SKILL.md` (59 Zeilen); DECISIONS 2026-11-07 "Ceremony scales with the change" (Quelle ponytail) und 2026-11-13 M023 (auch für Nachweis und Review). |
| 6 | Evals und öffentlicher Vergleich | **teilweise** | `evals/` mit 25 Fällen, Läufe in `KNOWLEDGE.md` ("Eval runs") festgehalten. Nicht in CI (keiner der drei Workflows ruft `claude plugin eval`). Immer mit `--ablation none` gelaufen, also nie gegen "ohne Plugin" (`evals/README.md`, Zeile 41). Verglichen wurden alte und neue Anweisungen (KNOWLEDGE, 2026-11-13). |
| 7 | Auf skills.sh, `license` in der Frontmatter | **nicht** | M019 vermerkt das Listing als Handlung des Operators. Kein Skill hat `license:`. |
| 8 | Eine Form für Verweise zwischen Skills, frische Subagenten | **teilweise** | Kein DECISIONS-Eintrag, keine Prüfregel. Skills nennen den nächsten Skill als `ytstack:<name>` und rufen ihn bewusst nicht auf (`spec/skills.md`, "No chaining"). Frischer Kontext für Subagenten steht in 15 Dateien (z. B. `code-review`, `coordinate`, `finish-lane`, `agents/verifier.md`). |
| 9 | Mehrere Hosts | **umgesetzt für Codex** | DECISIONS 2026-10-13 (drei Einträge), `docs/codex.md`; ein dritter Host ist als M020 geplant. |
| 10 | Artefaktmodell behalten | **umgesetzt und erweitert** | M022 (technischer Spec), M024 (Lanes, Fragen, `STANDING.md`), M025 (`RUNTIME.md`, `REVIEW.md`). |

### 2.2 Coordinator mode (laut `NOTICE`, Abschnitt "mattpocock/skills")

| Konzept | Upstream-Herkunft | Ort in ytstack |
|---|---|---|
| Eine koordinierende Sitzung, deren Gedächtnis sie überlebt und als Geschichte geschrieben ist | `in-progress/chief-of-staff` (Wiki, datierte Aussagen) | `skills/coordinate/SKILL.md` Schritt 3 und 12; `STANDING.md` mit UTC-Zeit und durchgestrichenen, nicht gelöschten Zeilen |
| Blockierende Kanten und eine Frontier bereiter Arbeit | `to-tickets`, `implement-spec`, `wayfinder` | `**Blocked by:**` in `slice-milestone`, `bin/ytstack-frontier` |
| Ein Claim vor jeder Arbeit | `wayfinder` (Zuweisung als Claim) | `LANES.md`, `ytstack-frontier claim` |
| Ein Brief mit prüfbaren Abschlusskriterien | `triage/AGENT-BRIEF.md`, `writing-for-agents` | `bin/ytstack-brief render/check`, `docs/ux/coordinator-format.md` |
| Ein gestuftes Skript für Schritte, die nur der Mensch darf | `wizard` | `skills/handover-step/SKILL.md`, `bin/ytstack-handover` |
| Eine Warteschlange entscheidungsreifer Fragen | `grilling` (Empfehlung je Frage), `loop-me` (Brief am Checkpoint) | `.ytstack/questions/`, `bin/ytstack-questions` |
| Retros, die in Prüfungen enden | `retro` | `skills/lane-retro/SKILL.md` Schritt 6 |

Sonst nennt nur `bin/ytstack-check` (Zeile 157) Pocock beim Namen. Kein DECISIONS-Eintrag erwähnt die Sammlung.

## 3. Skill für Skill

Urteile: **gleichwertig**, **ytstack stärker**, **Pocock stärker**, **Lücke** (ytstack hat nichts und es würde passen), **bewusst nicht** (passt nicht zu ytstack). Zeilen = Länge der upstream `SKILL.md`.

### Engineering (20)

| Skill (Zeilen) | Was er tut | ytstack-Gegenstück | Urteil |
|---|---|---|---|
| `ask-matt` (97) | Router über alle Skills mit Hauptfluss, Auffahrten und einem Entscheidungsbaum für Phasengrenzen | `using-ytstack` (per Hook eingespielt), die Beschreibungen, README-Diagramme | gleichwertig; der Phasengrenzen-Baum (weitermachen, leeren, übergeben, Subagent, verdichten) hat in ytstack kein Gegenstück außer `coordinate` Schritt 12 |
| `grill-with-docs` (7) | Ruft `grilling` und `domain-modeling` zusammen auf | `grill` (73) | Pocock stärker im Interview, ytstack stärker im Artefakt (schreibt `GRILL-<slug>.md` und den Meilenstein-Kontext) |
| `triage` (112) | Issues und fremde PRs durch Zustände führen, Behauptung prüfen, Agent-Brief schreiben | keins; `tracker:` in `STATE.md` | bewusst nicht (ytstack ist kein Tracker-Werkzeug); die Regel "erst die Behauptung reproduzieren" steckt in `signal-intake` und `incident` |
| `improve-codebase-architecture` (71) | Sucht in den Hot Spots der Historie nach flachen Modulen, HTML-Bericht, dann Interview | keins; `software-craftsmanship` ist passive Referenz | Lücke, niedrige Priorität |
| `setup-matt-pocock-skills` (120) | Drei Fragen je Repo: Tracker, Labels, Ort der Domänen-Doku | `init-project` (606), `adopt-brownfield` (679) | ytstack stärker im Ergebnis, Pocock viel billiger im Einstieg |
| `to-spec` (75) | Gespräch ohne weitere Fragen zu einem Spec im Tracker verdichten, Test-Seams vorab abstimmen | `plan-milestone` (`M###-CONTEXT.md`), `.ytstack/spec/` | gleichwertig; ytstack trennt Plan (Geschichte) und Spec (Ist-Zustand), Pocock nicht |
| `to-tickets` (105) | Vertikale Tracer-Bullet-Tickets mit blockierenden Kanten; Ausnahme für breite Refactorings (erst erweitern, dann umziehen, dann zurückbauen) | `slice-milestone` (257), `plan-task` (326) | gleichwertig; die Regel für breite Refactorings fehlt in ytstack |
| `implement` (17) | Ticket holen, TDD an vereinbarten Seams, Review, Commit | `plan-task` -> `test-driven-development` -> `verification-before-completion` -> `summarize-task`; `quick-task` (174) | ytstack stärker im Nachweis, Pocock schlanker |
| `implement-spec` (42) | Ganzer Spec auf einem Integrationsbranch, Implementer je Ticket über die Frontier, Merger-Subagent, Review am Ende | `spawn-milestone-team` (339), `coordinate` (220), `finish-lane` (435) | ytstack stärker (frischer Verifier je Slice, Gates vom Host, Merge am geprüften Commit) |
| `wayfinder` (128) | Riesige, unklare Vorhaben als Karte von Entscheidungs-Tickets; Nebel, Ziel, Außerhalb | `office-hours`, `grill`, `questions/` | Lücke; nur teilweise durch `questions/` gedeckt |
| `retro` (44) | Umgebung statt Code verbessern; mechanische Fehler werden Prüfungen | `retro` (530), `lane-retro` (219) | gleichwertig; `lane-retro` ist die direkte Übernahme |
| `prototype` (26) | Wegwerf-Prototyp für eine Entwurfsfrage, auf eigenem Branch als Quelle aufbewahrt | keins | Lücke, niedrige Priorität |
| `diagnosing-bugs` (138) | Zuerst eine enge, rot werdende Schleife bauen, minimieren, 3 bis 5 falsifizierbare Hypothesen, markierte Debug-Logs, Regressionstest nur an einem echten Seam | `systematic-debugging` (68, rendert superpowers) | Pocock stärker beim Abschlusskriterium der Reproduktion |
| `research` (12) | Hintergrund-Agent, Primärquellen, zitierte Markdown-Datei im Repo | keins; `docs/research/` entsteht per Hand-Brief | Lücke |
| `tdd` (38) | Seams vorher abstimmen, drei Anti-Muster (an Implementierung gekoppelt, tautologisch, horizontal), Refactoring gehört ins Review | `test-driven-development` (69, superpowers) | gleichwertig; Pocock schärfer bei tautologischen Tests |
| `domain-modeling` (74) | Begriffe gegen `GLOSSARY.md` prüfen, Szenarien, ADRs nur bei drei Bedingungen | `DECISIONS.md` (ADR-artig), Spec-Bereiche; kein Glossar | Lücke beim Glossar, gleichwertig bei ADRs |
| `codebase-design` (114) | Wortschatz für tiefe Module (Modul, Interface, Tiefe, Seam, Adapter) | `software-craftsmanship` (92) | gleichwertig, Pocock präziser im Wortschatz |
| `code-review` (89) | Zwei getrennte Achsen (Standards samt fester Smell-Liste, Spec) als parallele Subagenten, Berichte nicht vermischt | `code-review` (211), `visual-review` (271) | ytstack stärker (Runden-Grenze, angenommene Last, Risikoklasse, Linsen); Pocock stärker in der Trennung der Achsen |
| `pr` (170) | PR-Body: kleinste Visualisierung, Beleg vorher/nachher, Einbahn- oder Zweibahntür und Reichweite | `ship/references/pr-body.md` | gleichwertig in `ship`; Lücke in `finish-lane` |
| `wizard` (44) | Erzeugt ein interaktives Bash-Skript für Schritte, die nur ein Mensch kann | `handover-step` (264) | ytstack stärker (statische Prüfung, Quittung, Agent startet es nie) |

### Productivity (7)

| Skill (Zeilen) | Was er tut | ytstack-Gegenstück | Urteil |
|---|---|---|---|
| `grill-me` (7) | `grilling` ohne Dokumentation | `grill` | gleichwertig |
| `grilling` (30) | Interview in Runden über den Entscheidungsbaum; je Frage eine Empfehlung, die man mit "ja" annimmt; Fakten holt ein Subagent | `grill`; AskUserQuestion-Vertrag (`docs/ux/askuserquestion-format.md`); `coordinate` Schritt 8 | Pocock stärker für offene Interviews; ytstack hat Empfehlung und "erst nachsehen, dann fragen" schon |
| `handoff` (16) | Übergabe in den Temp-Ordner, nur Zeiger, empfohlene Skills, Geheimnisse geschwärzt | `handoff-session` (179) plus automatische Übergabe per Hook | ytstack stärker |
| `teach` (140) | Lern-Arbeitsplatz über mehrere Sitzungen | keins | bewusst nicht (kein Entwicklungsschritt) |
| `to-questionnaire` (54) | Fragebogen an die eine Person, die eine Entscheidung kennt | `questions/` (nur an den Operator) | bewusst nicht als Skill; Konzept teilweise vorhanden |
| `wait-what` (7) | Letzte Nachricht einfacher und im Projekt-Wortschatz neu sagen | keins; `docs/ux/writing-style.md` wirkt vorab | Lücke, klein (braucht ein Glossar) |
| `writing-for-agents` (81) | Schreiblehre für Agent-Dokumente: Zeiger, zwei Lasten, Hierarchie, Leitwörter, No-op-Test | `docs/ux/*.md`, `bin/ytstack-check` | Pocock stärker als Lehre; ytstack stärker in der mechanischen Prüfung. Der Wrapper aus M019 entfiel ("no consumer asked") |

### In-progress (relevant für den Entwicklungszyklus)

| Skill (Zeilen) | Was er tut | ytstack-Gegenstück | Urteil |
|---|---|---|---|
| `software-factory` (98) | Wortschatz für eine Agenten-Fabrik (Task, Trigger, Run, Runner, Orchestrator); langsam anfangen mit drei Bremsen; fünf Fragen je Task | M025 bis M027, `docs/research/2026-11-13-openai-software-factory.md` | gleichwertig; ytstack baut die Bremsen (Risiko-Weiche, Release-Watch), Pocock nur den Wortschatz. Die fünf Fragen je Task (vor allem "was verhindert doppelte Arbeit") sind in ytstack über Claims beantwortet |
| `chief-of-staff` (75) | Lang laufende Sitzung, alles in Subagenten, Wiki als datierte Geschichte, Retro auf jede fünfte Subagent-Sitzung | `coordinate`, `lane-retro` | ytstack stärker (Dateien statt Wiki, Host-Fakten mit Lesezeit) |
| `loop-me` (32) | Wiederkehrende Abläufe des Nutzers als Workflow-Specs erfragen | keins | bewusst nicht |
| `claude-handoff` (18) | Übergabe direkt an einen Hintergrund-Agenten per `claude --bg` | keins | bewusst nicht (host-spezifisch) |
| `setup-ts-deep-modules` (102) | dependency-cruiser so einrichten, dass Pakete nur über Einstiegsdateien erreichbar sind; zeigen, dass die Regel greift | keins | bewusst nicht als Skill (TypeScript-spezifisch); das Muster "Regel erst gelten lassen, wenn sie nachweislich anschlägt" passt zu `lane-retro` |

`misc/` (vier eingefrorene Skills) wurde nicht verglichen.

## 4. Unterschiede in der Haltung

**Größe.** Pocock: 27 Skills, 1.858 Zeilen `SKILL.md` (Mittel 69), drei Skills sind ein Satz, Zusammensetzung über den Skill-Aufruf. ytstack: 38 Skills, 10.424 Zeilen (Mittel 274), dazu der eingelesene Text von superpowers (`brainstorming` allein 316 Zeilen). Pocock hält die Disziplin über eine Regel: jedes Wort muss im Test gegen das Standardverhalten des Modells etwas ändern. ytstack hält sie über Verträge (Pflichtabschnitte, Preamble, Terminal State, Gates). Das Wachstum seit dem 2026-11-07 ist fast ganz neue Fähigkeit (M022 bis M027), nicht aufgeblähte alte Skills; billiger wird der Kontext dadurch trotzdem nicht.

**Wer einen Skill auslöst.** Pocock trennt hart: Orchestrierende Skills löst nur der Mensch aus und sie kosten keinen Platz in der Liste; Disziplinen erreicht das Modell selbst. ytstack lässt das Modell alles erreichen (`docs/concept.md` 4.1) und schützt sich mit Gates und Terminal States. Folge: Alle 38 Beschreibungen stehen in jeder Sitzung in der Liste.

**Artefakte gegen Tracker.** Pocock speichert Spec, Tickets und Entscheidungs-Karten im Issue-Tracker (GitHub, GitLab oder `.scratch/`), dazu `GLOSSARY.md` und `docs/adr/`. ytstack speichert alles unter `.ytstack/` mit festen Pfaden und kennt einen Tracker nur als Feld. Vorteil ytstack: Ein frischer Agent, ein Host ohne Hooks und ein Eval-Fixture finden alles ohne Netzwerk. Vorteil Pocock: Menschen arbeiten dort, wo sie ohnehin sind, und die Frontier ist im Tracker sichtbar.

**Interview gegen Frage-Widget.** Pocock stellt offene Fragen im Chat, eine ganze Runde auf einmal, jede mit Empfehlung; das Widget ist ausdrücklich abgelehnt, weil es zu Multiple Choice drängt. ytstack stellt Entscheidungen über AskUserQuestion mit Re-ground, Empfehlung und Optionen, eine Frage zur Zeit, und sammelt Gates seit M023 an der Slice-Grenze. Beides ist begründet: ytstack fragt nach Entscheidungen mit wenigen Optionen, Pocock nach Gedanken, die noch keine Optionen haben. `grill` steht dazwischen und nutzt den superpowers-Ablauf.

**Wie Spec und Tickets fließen.** Pocock: Gespräch, dann `to-spec` (keine Fragen mehr), dann `to-tickets` (Kanten), dann `implement` je Ticket mit leerem Kontext oder `implement-spec`. ytstack: `office-hours`, `grill`, `plan-milestone`, `slice-milestone` (Kanten), `plan-task` je Aufgabe mit Dateien und Prüfkommando, `summarize-task` mit Nachweis. ytstack hat einen Schritt mehr (der Plan je Aufgabe) und dafür Nachweis und Abweichungen in jeder Zusammenfassung. Pocock hält Dateipfade bewusst aus Specs heraus, weil sie veralten; ytstack schreibt sie in Pläne und gleicht den Spec mechanisch nach (`ytstack-spec drift`).

**Review und Übergabe.** Pocock reviewt einmal, zwei Achsen, ohne Runden-Grenze, ohne Risikoklasse, und überlässt den Merge dem Menschen. ytstack begrenzt Runden, verlangt die angenommene Last, stuft das Risiko ein und lässt je Bereich Merges ohne Menschen zu (M025). Übergaben: Pocock schreibt eine Datei in den Temp-Ordner und regelt per Entscheidungsbaum, wann man sie braucht; ytstack schreibt automatisch vor jeder Verdichtung und auf Wunsch eine Hand-Übergabe.

**Einrichtung je Repo.** Pocock: drei Fragen, drei kleine Dateien unter `docs/agents/`, ein Block in `CLAUDE.md`. ytstack: sechs Artefakte, Spec, Präferenzen; bei bestehendem Code ein eigener Skill. Das ist der größte Unterschied in der Einstiegshürde.

**Wie der Umfang gehalten wird.** Beide haben dieselbe Hürde: nur beobachtete Fehler zählen (`SCOPE.md`; ytstack `AGENTS.md` "Speculative features", `docs/concept.md` 3.7). Pocock führt abgelehnte Ideen in `.out-of-scope/` mit Begründung und früheren Anfragen; ytstack hält sie in "Options considered" der DECISIONS-Einträge und in 3.2 "Explicitly skipped".

**Ehrliche Schwächen von ytstack**, die der Vergleich zeigt:

- Die Größe aus Abschnitt 2.1 Nr. 3 ist ungeprüft gegen den Nutzen: Kein Eval-Lauf hat gemessen, ob ein Wrapper das Verhalten gegenüber dem bloßen Modell ändert (`--ablation none`). Bei den frischen Fällen bestehen alte und neue Anweisungen gleich (KNOWLEDGE, 2026-11-13).
- Der eigene Wortschatz wächst (Lane, Gate, Linse, Boden, Decke, Route, Frontier, stehende Anweisung, Bereich, Übergabe) und steht verteilt in den Formatdateien unter `docs/ux/` (`coordinator-format.md`, `review-policy-format.md`, `runtime-format.md`, `spec-format.md`). Ein Glossar gibt es weder für ytstack noch für die Projekte, die es nutzen. Genau das nennt Pocock als zweiten Hauptfehler von Agenten.
- Das Abweichen von Empfehlung 2 ist nirgends entschieden, nur nicht gebaut.
- Kein Weg für Recherche, obwohl ytstack selbst drei Recherche-Notizen per Hand-Brief erzeugt hat.
- Verbreitung: Pocock hat sechs Installationswege und skills.sh; ytstack Claude Code und Codex über einen Katalog.

## 5. Empfehlungen

Nur Konzepte, nie Text (`AGENTS.md`: "concepts yes, prose no"). Nach Wert geordnet. Wo kein beobachteter Fehler belegt ist, steht das dabei; nach ytstacks eigener Regel wartet ein solcher Punkt, bis einer auftritt.

1. **Recherche-Notizen als festes Format, mit Upstream-Stand.** Konzept aus `research`: Primärquellen, jede Aussage mit Quelle, Ergebnis als Datei im Repo, Arbeit im Hintergrund. *Kleinste Änderung:* eine Formatdatei `docs/ux/research-note-format.md` (Quellenlage mit Commit oder Abrufdatum, Fakt und Urteil getrennt, Vergleich gegen den zuletzt gelesenen Stand) und eine Zeile in `AGENTS.md`; kein neuer Skill (`docs/concept.md` 3.7, Tor 1). *Beobachtetes Problem:* Drei Notizen (2026-11-07, 2026-11-13, diese) entstanden aus Hand-Briefs mit wechselndem Aufbau. Der Brief zu dieser Notiz ging von neuen Upstream-Skills aus, die es seit Wochen gab; ein Vergleich mit dem Stand in `NOTICE` (`4ae2317`) hätte das in einer Zeile gezeigt.

2. **Nutzen der großen Skills messen, dann kürzen.** Konzept aus `writing-for-agents`: ob ein Satz etwas bewirkt, entscheidet ein Lauf, nicht eine Debatte; Sätze ohne Wirkung werden ganz gestrichen. *Kleinste Änderung:* die vorhandenen Fälle `code-review`, `fresh-bugfix` und `grill` einmal ohne `--ablation none` laufen lassen und das Ergebnis in `KNOWLEDGE.md` eintragen; danach einen No-op-Durchgang durch die drei längsten eigenen Skills (`adopt-brownfield`, `init-project`, `summarize-task`). *Beobachtetes Problem:* Die Skills sind seit dem 2026-11-07 auf das Dreifache gewachsen, Empfehlung 3 ist offen, und der einzige Vergleich, den es gibt, zeigt bei kleinen Projekten keinen Gewinn (KNOWLEDGE, 2026-11-13).

3. **Ein Abschnitt "Begriffe" im Spec.** Konzept aus `domain-modeling` und `wait-what`: ein knappes Glossar ohne Implementierung, gegen das Begriffe geprüft werden, und auf das man bei Unverständnis zurückgeht. *Kleinste Änderung:* `docs/ux/spec-format.md` erlaubt in `SPEC.md` einen Abschnitt mit höchstens 15 Begriffen, je eine Zeile, `ytstack-spec lint` prüft die Länge; ytstack trägt dort seinen eigenen Wortschatz ein. Kein eigenes `GLOSSARY.md`, damit die Pfade fest bleiben. *Beobachtetes Problem:* Zehn eigene Begriffe, verteilt über vier Formatdateien (Abschnitt 4); ein Fehlverstehen durch einen Nutzer ist nicht belegt. Kandidat.

4. **Abschlusskriterium für die Reproduktion beim Debuggen.** Konzept aus `diagnosing-bugs`: Erst wenn ein Kommando existiert, das schon einmal gelaufen ist und genau diesen Fehler rot zeigt, beginnt die Suche nach Ursachen; markierte Debug-Ausgaben werden am Ende per Suche entfernt; fehlt ein Seam für den Regressionstest, ist das ein Befund für `KNOWLEDGE.md`. *Kleinste Änderung:* drei Sätze in den Invocation Notes von `skills/systematic-debugging/SKILL.md` (der vendored Text bleibt unberührt). *Beobachtetes Problem:* keins in den ytstack-Unterlagen. Messpunkt wäre der Eval-Fall `fresh-bugfix`. Kandidat.

5. **Breite Refactorings beim Schneiden.** Konzept aus `to-tickets`: Eine mechanische Änderung, die überall bricht, wird nicht vertikal geschnitten, sondern als Erweitern, Umziehen in Stapeln, Zurückbauen, mit den Kanten dazwischen. *Kleinste Änderung:* ein Absatz in `skills/slice-milestone/SKILL.md` bei "Blocked by". *Beobachtetes Problem:* Die Migration mit über hundert Arbeitspaketen (DECISIONS 2026-11-13, M024) ist genau dieser Fall; ob das Schneiden dort scheiterte, ist nicht festgehalten. Kandidat.

6. **Umkehrbarkeit als eigene Angabe.** Konzept aus `pr`: Einbahn- oder Zweibahntür neben der Reichweite. *Kleinste Änderung:* eine Zeile `Reversible: yes|no` in der Klassen-Angabe des Reviewers (`code-review`, M025) und in `ship/references/pr-body.md`. *Beobachtetes Problem:* keins; `ytstack-risk floor` behandelt Migrationen schon als nie gering, was den häufigsten Einbahn-Fall abdeckt. Niedrigste Priorität.

**Nicht übernehmen:**

- *Den Tracker als Ablage für Spec, Tickets und Karten* (`to-spec`, `to-tickets`, `triage`, `wayfinder`, `setup-matt-pocock-skills`). ytstacks feste Pfade sind die Grundlage für Evals, Hosts ohne Hooks und Wiederaufnahme nach Kontextverlust (DECISIONS 2026-11-13, M022).
- *Kleine Skills durch Weglassen der Gates.* Bei ytstack ist der Nachweis das Produkt (M023, M025). Kürzen ja, aber über Messung (Empfehlung 2), nicht über Streichen von Prüfungen.
- *Die Ablehnung von AskUserQuestion für alles.* ytstack fragt Entscheidungen ab, und dafür ist das Widget mit Empfehlung richtig. Offen ist nur `grill` (Frage 2).
- *Fragen ohne Grenze und Skills ohne Schutz vor Rekursion.* ytstack begrenzt Review-Runden und Arbeit bewusst (M023); das ist der entgegengesetzte, belegte Weg.
- *Einen Router-Skill wie `ask-matt`.* `using-ytstack` und die Beschreibungen tun das, und ein Router muss bei jeder Skill-Änderung mitgepflegt werden.
- *`teach`, `loop-me`, `to-questionnaire`, `claude-handoff`, `setup-ts-deep-modules`, `improve-codebase-architecture`, `prototype`.* Außerhalb des Entwicklungszyklus, host-spezifisch, sprachspezifisch oder ohne beobachteten Bedarf. Die letzten beiden können zurückkommen, wenn ein Projekt den Fehler zeigt.
- *Die Smell-Liste aus `code-review` als Text.* Wenn ytstack eine solche Basis will, als eigene Formulierung in `software-craftsmanship`, nicht als Kopie.

## 6. Offene Fragen an den Operator

1. **Sollen Skills, die nur auf das Wort eines Menschen laufen sollen, `disable-model-invocation: true` bekommen?** Kandidaten wären `ship`, `finish-branch`, `reconcile`, `retro`, `document-release`. Daran hängt die Grundhaltung aus `docs/concept.md` 4.1 (der Agent wählt) gegen weniger Kontext je Sitzung und weniger ungewollte Starts. Empfehlung: nein als Regel; die Frage erst entscheiden, wenn ein ungewollter Start oder `/skill-doctor` einen Anlass zeigt, und den Verzicht bis dahin als DECISIONS-Eintrag festhalten, weil M019 ihn als Ziel hatte. **Entschieden 2026-11-14:** nein; Modelle arbeiten autonom (DECISIONS "Models work autonomously; no skill gets `disable-model-invocation`").
2. **Soll `grill` ein offenes Interview in Runden führen dürfen statt einer AskUserQuestion-Frage zur Zeit?** Entscheidungs-Gates blieben beim Widget. Empfehlung: ja für `grill`, weil dort noch keine Optionen existieren; das wäre eine Ausnahme im Vertrag `docs/ux/askuserquestion-format.md` und braucht einen DECISIONS-Eintrag.
3. **Gibt es eine Größengrenze für Skills?** Zum Beispiel ein Rumpf von höchstens 300 Zeilen, der Rest in `references/`, geprüft von `bin/ytstack-check`. Empfehlung: erst nach der Messung aus Empfehlung 2 festlegen, damit die Grenze an Wirkung hängt und nicht an einer Zahl.

## Quellen

- Upstream am Commit `5863806`: https://github.com/mattpocock/skills/tree/5863806dd4e15c63174bee4e7515a4256792ecfa (Pfade wie oben, z. B. `skills/engineering/code-review/SKILL.md`, `skills/productivity/grilling/SKILL.md`, `skills/in-progress/software-factory/SKILL.md`, `.out-of-scope/native-question-tool.md`, `SCOPE.md`, `CHANGELOG.md`)
- Vergleich `4ae2317...5863806` per `gh api repos/mattpocock/skills/compare`
- ytstack: `NOTICE`, `bin/ytstack-check`, `docs/concept.md`, `.ytstack/DECISIONS.md`, `.ytstack/ROADMAP.md`, `.ytstack/KNOWLEDGE.md`, `.ytstack/spec/skills.md`, `evals/README.md`, `docs/ux/skill-structure.md`, `skills/*/SKILL.md`
- Frühere Notizen: `docs/research/2026-11-07-notes/developer-skills-landscape.md`, `docs/research/2026-11-13-openai-software-factory.md`
