# Kimi-native ytstack-Integration: Best Practices und Support-Grenzen

**Stand: 2026-11-14. Auslöser: Issue #30 / M020. Methodik: offizielle Kimi-Dokumentation, aktueller Upstream-Source an Commit [`f082f04`](https://github.com/MoonshotAI/kimi-code/commit/f082f04a093a3e71a2263c5461d52507dc31f83a), Issues/PRs und Release-Notes, reale Plugin-Manifeste sowie lokale native Installation und Skill-Aktivierung mit Kimi 2.5.3. Keine externe LLM-Nutzung; die lokalen Aktivierungstests verwenden ein kontrolliertes OpenAI-Fixture.**

## Kurzurteil

Der native Plugin-Ansatz aus S01 ist richtig: gemeinsamer `skills/`-Baum, `ytstack:<name>`-Namespace, statischer Bootstrap über `sessionStart.skill` und Adapter über `systemPromptPath`. Die ursprüngliche S02-Annahme ist dagegen falsch: **SessionStart-Hook-Stdout ist im aktuellen Kimi-Source kein Kontextkanal.** Ein Plain-Output-Schalter bleibt nützlich, aber Plain SessionStart allein injiziert keinen Projektzustand.

Für dynamischen Projektzustand ist `UserPromptSubmit` der nachweislich konsumierte Hook-Kanal. Die empfohlene ytstack-Architektur ist eine kleine Pending-Bridge: SessionStart und PostCompact markieren Kontext als bereit, UserPromptSubmit liefert ihn beim nächsten echten User-Prompt aus. Das ist eine ytstack-Empfehlung aus den Source-Verträgen, kein etablierter Kimi-Standard und vor Implementierung live zu testen.

Für den PR auf ytstack 0.8.0 wurde der ursprüngliche externe gstack-Ansatz verworfen. Die sechs gstack-adaptierten Skills sind seit 0.6.0 selbst enthaltene ytstack-Skills. Kimi lädt sie unter `ytstack:<name>` aus dem gemeinsamen Plugin; keine Installation, `extra_skill_dirs` oder Exact-path-Auswahl ist dafür nötig.

## Bewiesene Plattformverträge

### 1. Native Plugins und Namespaces sind die richtige Verpackung

Die [Plugin-Dokumentation](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/plugins.html) unterstützt `kimi.plugin.json` und `.kimi-plugin/plugin.json`, `skills`, `sessionStart.skill`, `systemPromptPath`, `skillInstructions` und Plugin-Hooks. Plugin-Skills werden als `<plugin-id>:<skill-name>` adressiert; ein bare Name löst nicht zum Plugin-Skill auf.

Der lokale S01-Test mit 2.5.3 installierte `.kimi-plugin/plugin.json` aus einem Pfad mit Leerzeichen in ein frisches `KIMI_CODE_HOME`: 31 ytstack-Skills erschienen unter `ytstack:<name>`, ohne `extra_skill_dirs` für ytstack. Die Wahl `.kimi-plugin/plugin.json` ist damit funktional belegt. Root-`kimi.plugin.json` ist bei den untersuchten Community-Plugins häufiger, aber nicht technisch erforderlich.

Moonshots [WebBridge-Manifest](https://github.com/MoonshotAI/kimi-code/blob/main/plugins/official/kimi-webbridge/kimi.plugin.json) enthält `$schema`; die Manifeste von [Apify](https://github.com/apify/apify-kimi-code-plugin/blob/main/kimi.plugin.json) und [VirusTotal](https://github.com/VirusTotal/virustotal-mcp/blob/main/plugins/kimi/kimi.plugin.json) kommen ohne aus. Die genannte Schema-URL lieferte beim Fetch keine JSON-Schema-Datei, deshalb ist `$schema` keine verifizierte Validierungsgrundlage. Die native Installation und Kimi-Diagnostik sind die maßgeblichen Checks.

### 2. `sessionStart.skill` liefert statische Instructions, keine Projektabfrage

Der aktuelle [`agentPluginService.ts`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core-v2/src/agent/plugin/agentPluginService.ts) rendert deklarierte Skills als `<plugin_session_start>`-System-Reminder. Die [Upstream-Tests](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core-v2/test/features/skill/catalog/plugin-session-start.test.ts) belegen:

- Injektion beim ersten Agent-Schritt
- keine Wiederholung in derselben Session
- Wiederherstellung aus persistierter History ohne Duplikat
- Auflösung per Plugin-Identität bei einem Namenskonflikt

Das ist die richtige Heimat für `using-ytstack`. Der Inhalt bleibt vom Autor geschrieben und statisch; der Hook ersetzt weder das Lesen von STATE.md noch eine dynamische Kontextabfrage.

`systemPromptPath` ist für stabile Adapter-Regeln geeignet. [PR #2314](https://github.com/MoonshotAI/kimi-code/pull/2314) dokumentiert 32 KB pro Inline-/Datei-Beitrag und 64 KB aggregiertes Prompt-Budget. Der aktuelle ytstack-Adapter liegt weit darunter. Nach Installation oder Änderung ist `/reload` beziehungsweise `/new` weiterhin erforderlich.

### 3. SessionStart-Stdout wird nicht konsumiert

Das ist durch mehrere unabhängige Ebenen abgesichert:

- Der klassische [`Session.triggerSessionStart`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core/src/session/index.ts) ruft den Hook auf, verwertet aber das Ergebnis nicht.
- Der aktuelle v2-[`SessionExternalHooksService`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core-v2/src/features/externalHooks/session/sessionExternalHooksService.ts) ruft ebenfalls nur `runner.trigger()` ohne Ergebnisverwendung auf.
- Die aktuelle [Hook-Output-Pipeline](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core/src/session/hooks/runner.ts) kennt `message` und Permission-Felder, nicht `additionalContext`.
- [Issue #4438](https://github.com/MoonshotAI/kimi-code/issues/4438) belegt mit 2.3.2 einen realen Token-Test: SessionStart feuerte, der Token erreichte das Modell nicht; UserPromptSubmit funktionierte als Kontrolle.
- [#1896](https://github.com/MoonshotAI/kimi-code/issues/1896) und [#4000](https://github.com/MoonshotAI/kimi-code/issues/4000) beschreiben denselben fehlenden Kanal. Die Tickets bleiben offen; ihr Alter allein ist nicht der Beweis, sondern stimmt hier mit dem aktuellen Source überein.

**Konsequenz:** kein Claim "Kimi erhält SessionStart-Kontext", nur weil der Hook Exit 0 und Plain Text ausgibt. Das ursprüngliche Issue #30 und der bisherige M020-S02-Plan müssen diese Grenze ausdrücklich korrigieren.

### 4. UserPromptSubmit ist der funktionierende Kontextkanal

Der aktuelle [`agentExternalHooksService.ts`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core-v2/src/features/externalHooks/agent/agentExternalHooksService.ts) hängt nicht-blockierende Hook-Teile an den echten User-Prompt. [`userPrompt.ts`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core-v2/src/features/externalHooks/internal/userPrompt.ts) verwendet dafür `message` oder Plain Stdout; strukturierte Output ohne `message` wird nicht als `additionalContext` interpretiert.

Das Payload-Feld `prompt` ist ein Content-Part-Array, kein String. Die gemeinsame `yt_read_stdin` liest nur `cwd`, `session_id` und weitere kompatible Felder, daher ist das für die bestehenden ytstack-Skripte unkritisch. Ein Test muss die reale Array-Form verwenden.

Der Community-Shim von [Fusengine](https://github.com/Fusengine/kimi-code/blob/main/scripts/hooks/kimi-hook-shim.mjs) trifft unabhängig dieselbe Unterscheidung: Kontext nur über UserPromptSubmit, Projekt-`cwd` aus dem Payload statt dem Plugin-Prozessverzeichnis. Das ist ein Praxisbeleg, keine zu kopierende Implementierung.

### 5. Compaction und SessionEnd brauchen echte Grenzen

Laut [Hook-Dokumentation](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html) und aktuellem Source:

- `PreCompact` ist observation-only; Rückgabewerte werden ignoriert. Der vorhandene Hook darf weiterhin das Auto-Handoff als Seiteneffekt schreiben, aber keine Ausgabe als Compaction-Anweisung erwarten.
- `PostCompact` feuert nach erfolgreicher Compaction, wird aber im klassischen [`full.ts`](https://github.com/MoonshotAI/kimi-code/blob/f082f04a093a3e71a2263c5461d52507dc31f83a/packages/agent-core/src/agent/compaction/full.ts) und in v2 fire-and-forget behandelt. Sein Stdout ist kein Reinjectionskanal.
- `SessionEnd` besitzt `exit` und `archive`, feuert aber nicht beim Idle-Unload einer `kimi web`-Session und nicht beim späteren Archivieren/Löschen einer solchen entladenen Session. Ein transparentes Reload erzeugt auch kein neues SessionStart.
- Hooks sind fail-open und dürfen laut Doku nie die einzige Sicherheitsbarriere sein. ytstack darf Hook-Ausführung nicht mit garantierter Persistenz verwechseln.

## Empfohlenes S02-Design

### Statische Ebene

1. `sessionStart.skill: using-ytstack` behalten.
2. `systemPromptPath: ./kimi/adapter.md` behalten.
3. Keine ytstack-Installation über `extra_skill_dirs`, keine kopierten Skill-Bäume.

### Dynamische Ebene: Pending-Bridge

**Empfehlung, noch kein nachgewiesener Plattformstandard:**

1. **SessionStart**: Der Kimi-Helper ruft das gemeinsame `hooks/session-start` mit explizitem Plain-Modus auf und speichert den Kontext als per-Session pending im bestehenden Out-of-tree-State. Der Hook selbst erwartet keine Kontextaufnahme.
2. **PreCompact**: Das vorhandene Auto-Handoff bleibt unverändert.
3. **PostCompact**: Der Helper erzeugt erneut pending Kontext, weil die bisherige History komprimiert wurde.
4. **UserPromptSubmit**: Nur bei vorhandenem pending Kontext gibt der Helper diesen als Plain Stdout aus und konsumiert die Markierung atomar. Ohne pending bleibt er still.
5. **SessionEnd**: Das vorhandene Journal bleibt unverändert; fehlende Web-Unload-/Archive-Events werden als Support-Grenze dokumentiert.

Diese Variante erhält ytstacks Semantik "Startup/Resume/nach Compaction" und vermeidet, die volle Directive bei jedem Prompt erneut zu injizieren. Der Preis sind zwei zusätzliche Events, ein kleiner Zustandsmarker und deutlich mehr Concurrency-/Replay-Tests.

Die einfachere Alternative ist UserPromptSubmit bei jedem Prompt ohne Pending-State. Sie ist aktueller und weniger komplex, injiziert aber jedes Mal Kontext, verändert Token-/Latenzkosten und wiederholt die Directive. Sie ist kein stiller Ersatz für SessionStart und sollte nur bewusst als vereinfachter Modus gewählt werden.

Falls die Bridge auf einer unterstützten Kimi-Version nicht zuverlässig feuert, bleibt `ytstack:resume-session` der ehrliche Fallback. Kein manueller Fallback darf als automatische Injection ausgegeben werden.

## gstack: verworfener externer Ansatz und PR-Integration

Die ursprüngliche Recherche prüfte eine unabhängige gstack-Installation und Kimis exakte Skill-Pfad-Auswahl, um gleichnamige Original- und Wrapper-Skills zu unterscheiden. Vor dem PR hat sich die Basis geändert: Seit ytstack 0.6.0 sind die sechs ausgewählten gstack-Skills eigene, selbst enthaltene ytstack-Adaptationen. Diese Entscheidung ersetzt die externe Auflösung vollständig.

Für 0.8.0 ist deshalb die einfachere und korrekte Lösung: keine gstack-Installation, kein zusätzliches Skill-Verzeichnis und keine Exact-path-Logik im Adapter. `ytstack:office-hours`, `ytstack:plan-ceo-review`, `ytstack:plan-eng-review`, `ytstack:retro`, `ytstack:ship` und `ytstack:document-release` laden aus demselben verwalteten Plugin wie alle anderen Skills. Der Livetest prüft ihre tatsächlichen Pfade und die Trennung von einem gleichnamigen Projekt-Override.

## Reale Plugin-Muster, die wir übernehmen sollten

| Projekt | Relevantes Muster | Übernahme für ytstack |
| --- | --- | --- |
| Moonshot WebBridge | kleines natives Manifest, deklarierte Skills, klare Interface-Metadaten | Manifest schlank halten; keine ungenutzten Felder |
| Apify | `sessionStart.skill` als statischer Intent-Router; Fähigkeits- und Auth-Checks vor Ausführung | `using-ytstack` als Router; echte Capability statt Tool-Namen prüfen |
| VirusTotal | ausführliche Trust-, Credential-, Netzwerk-, Reload- und Support-Grenzen; keine Hooks | S03 muss Install, Reinstall, Reload, selbst enthaltene Skills und fehlende Events dokumentieren |
| Fusengine | `${KIMI_PLUGIN_ROOT}` mit Quoting, Payload-`cwd`, UserPromptSubmit für Kontext | Gemeinsame Skripte über dünnen Helper aufrufen, niemals Plugin-Cwd als Projekt-Cwd verwenden |

Keines dieser Beispiele ersetzt ystacks eigene Lifecycle-Verifikation. VirusTotal braucht keine Hooks; die große Fusengine-Sammlung besitzt eigene Infrastruktur und Abhängigkeiten, die wir nicht importieren.

## Versionierung und Verifikation

- Lokal verifiziert: **Kimi 2.5.3**.
- Neuestes stabiles Release bei dieser Recherche: **2.6.2 vom 2026-11-13** ([Releases](https://github.com/MoonshotAI/kimi-code/releases)).
- 2.6.0 enthält relevante Änderungen an Skill-Path-Auswahl, Session-API und Skill-Prompt-Verhalten. Die Release-Notes nennen außerdem Reload-Fixes für extra Skill-Directories.
- Die offenen interaktiven Hook-Tickets [#2779](https://github.com/MoonshotAI/kimi-code/issues/2779) und [#2070](https://github.com/MoonshotAI/kimi-code/issues/2070) beschreiben ältere Versionen. [PR #2822](https://github.com/MoonshotAI/kimi-code/pull/2822) ist weiterhin offen. Sie sind als Risiko und manueller Regressionstest relevant, nicht als Beweis, dass 2.6.2 noch betroffen ist.

Vor einem Support-Claim braucht M020:

1. Packaging-Tests ohne Kimi weiterhin in CI.
2. Native Live-Suite auf 2.5.3 und aktuellem Stable, ohne reale Credentials.
3. Startup, Resume, PreCompact, PostCompact, UserPromptSubmit und echten SessionClose; kein Idle-Unload als SessionEnd-Ersatz.
4. Same-Name-Test: `ytstack:<name>` bleibt an das verwaltete Plugin gebunden, während ein bare Projekt-Override separat aktiviert wird.
5. Dieselben Namespace- und Override-Assertions auf 2.5.3 und 2.6.x.
6. Einen realen Modell-Smoke-Test für automatische ytstack-Skill-Auswahl als separat autorisierten Operator-Schritt. Das Dummy-Modell beweist Host-Mechanik, nicht semantische Auswahl.

## Auswirkungen auf M020

- **S01 bleibt valide:** native Verpackung, Namespace und gemeinsame Skills. Die gstack-Fixtures werden durch Aktivierung der sechs internen Adaptationen ersetzt.
- **S02 muss neu geplant werden:** Plain SessionStart allein erfüllt das Exit-Kriterium nicht. UserPromptSubmit, PostCompact, Pending-State und die Support-Grenzen gehören in Tests und Implementierung.
- **Der Kimi-Adapter braucht keine externe gstack-Auflösung:** alle sechs Adaptationen verwenden ihren qualifizierten ytstack-Namen.
- **S03 muss Versionen und Grenzen dokumentieren:** getestete Versionen, Reinstall/Reload, Plugin-User-Scope, selbst enthaltene gstack-Adaptationen, Hook-Fail-open, Web-SessionEnd und manuelle Fallbacks.
- **Keine Issue-Schließung aus dieser Recherche.** #30 bleibt offen bis Lifecycle, Dokumentation und die aktuelle Stable-Verifikation tatsächlich vorliegen.

## Quellenindex

Primär:

- [Kimi Plugins](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/plugins.html)
- [Kimi Skills](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/skills.html)
- [Kimi Hooks](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html)
- [Kimi Configuration](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/config-files.html)
- [Kimi Source an f082f04](https://github.com/MoonshotAI/kimi-code/tree/f082f04a093a3e71a2263c5461d52507dc31f83a)

Upstream-Probleme und Design:

- [#1896: SessionStart und Compact-Kontext](https://github.com/MoonshotAI/kimi-code/issues/1896)
- [#4000: Memory-Integrationsgrenzen](https://github.com/MoonshotAI/kimi-code/issues/4000)
- [#4438: realer SessionStart-Token-Test](https://github.com/MoonshotAI/kimi-code/issues/4438)
- [#2779: interaktive Hook-Regression](https://github.com/MoonshotAI/kimi-code/issues/2779)
- [PR #2314: Plugin-System-Prompt](https://github.com/MoonshotAI/kimi-code/pull/2314)
- [PR #4690: exakte Skill-Pfad-Auswahl](https://github.com/MoonshotAI/kimi-code/pull/4690)

Reale Plugins und gstack:

- [Moonshot WebBridge](https://github.com/MoonshotAI/kimi-code/tree/main/plugins/official/kimi-webbridge)
- [Apify Kimi Plugin](https://github.com/apify/apify-kimi-code-plugin)
- [VirusTotal Kimi Plugin](https://github.com/VirusTotal/virustotal-mcp/tree/main/plugins/kimi)
- [Fusengine Kimi Plugins](https://github.com/Fusengine/kimi-code)
- [gstack Kimi-Host-Entscheidung #1072](https://github.com/garrytan/gstack/issues/1072)
