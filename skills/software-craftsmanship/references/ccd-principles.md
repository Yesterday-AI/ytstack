# Clean Code Developer (CCD) — Prinzipien & Grade

Das CCD-Wertesystem ist ein Stufenmodell für kontinuierliche Verbesserung in der Softwareentwicklung.
Kein einmaliges Zertifikat — ein Kreislauf. Wer alle Grade durchlaufen hat, beginnt wieder von vorne.

Quelle: [clean-code-developer.de](https://clean-code-developer.de)

---

## Die 4 Werte

```
Evolvierbarkeit  ←  Code muss sich ändern lassen
Korrektheit      ←  Code muss das Richtige tun
Produktionseffizienz  ←  Schnell liefern ohne Ballast
Kontinuierliche Verbesserung  ←  Lernen, immer besser werden
```

---

## 1. Grad — Rot 🔴 (Grundhaltung)

> Absolute Basis. Haltung vor Technik.

**Prinzipien:**
- **DRY** — Don't Repeat Yourself
- **KISS** — Keep it simple, stupid
- Vorsicht vor vorzeitigen Optimierungen
- **FCoI** — Favour Composition over Inheritance
- **IOSP** — Integration Operation Segregation Principle
- Die Pfadfinderregel (Code besser hinterlassen als vorgefunden)
- Root Cause Analysis (Ursachen statt Symptome beheben)

**Praktiken:**
- Versionskontrollsystem einsetzen
- Einfache Refaktorisierungsmuster anwenden
- Täglich reflektieren

---

## 2. Grad — Orange 🟠 (Automatisierung beginnt)

> Fundamentale Prinzipien + erste Automatisierung von Korrektheitsprüfungen.

**Prinzipien:**
- **SLA** — Single Level of Abstraction
- **SRP** — Single Responsibility Principle
- **SoC** — Separation of Concerns
- Source Code Konventionen

**Praktiken:**
- Issue Tracking
- Automatisierte Integrationstests
- Lesen, Lesen, Lesen
- Reviews

---

## 3. Grad — Gelb 🟡 (Unit Tests + OOP-Prinzipien)

> Tests unter der Oberfläche. Einzelne Klassen isoliert testbar machen.

**Prinzipien:**
- **OCP** — Open Closed Principle
- **Tell, don't ask**
- **Law of Demeter**
- **ISP** — Interface Segregation Principle
- **DIP** — Dependency Inversion Principle
- **LSP** — Liskov Substitution Principle
- **PLA** — Principle of Least Astonishment
- **IHP** — Information Hiding Principle

**Praktiken:**
- Automatisierte Unit Tests
- Mockups / Testattrappen
- Code Coverage Analyse
- Teilnahme an Fachveranstaltungen
- Komplexe Refaktorisierungen

---

## 4. Grad — Grün 🟢 (CI + Architekturwerkzeuge)

> Automatisierung bis zur Produktion. Abhängigkeiten sichtbar machen.

**Prinzipien:**
- (Vertiefung der vorherigen Grade)

**Praktiken:**
- **Continuous Integration**
- Statische Codeanalyse / Metriken
- Inversion of Control Container
- Erfahrung weitergeben
- Messen von Fehlern

---

## 5. Grad — Blau 🔵 (Architektur + Delivery)

> Deployment automatisieren. Architektur bewusst gestalten. Iterativ vorgehen.

**Prinzipien:**
- Entwurf und Implementation überlappen nicht
- Implementation spiegelt Entwurf
- **YAGNI** — You Ain't Gonna Need It

**Praktiken:**
- **Continuous Delivery**
- Iterative Entwicklung
- Komponentenorientierung
- **Test First** (TDD)

---

## Überblick: Prinzipien nach Grad

| Prinzip | Grad |
|---|---|
| DRY, KISS, IOSP, FCoI | 🔴 Rot |
| SRP, SoC, SLA | 🟠 Orange |
| OCP, Law of Demeter, Tell don't ask | 🟡 Gelb |
| ISP, DIP, LSP, IHP, PLA | 🟡 Gelb |
| IoC | 🟢 Grün |
| YAGNI, Iterative Entwicklung, TDD | 🔵 Blau |

## Überblick: Praktiken nach Grad

| Praktik | Grad |
|---|---|
| VCS, einfache Refaktorierungen | 🔴 Rot |
| Integrationstests, Issue Tracking | 🟠 Orange |
| Unit Tests, Mocks, Coverage | 🟡 Gelb |
| CI, Statische Analyse, IoC Container | 🟢 Grün |
| CD, Test First, Komponentenorientierung | 🔵 Blau |
