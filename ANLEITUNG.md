# 📘 Sel01-Tweaker — Anleitung (für ALLE, ganz einfach)

Dieses Programm macht dein **Windows 11 schneller und sauberer** — mit einem
Klick. Es entfernt Müll-Apps, Werbung, Spionage (Telemetrie), Copilot/KI, stellt
die besten Leistungs-Einstellungen ein und räumt den Arbeitsspeicher auf.

**Du musst nichts können. Du musst nichts einstellen. Doppelklick — fertig.**

---

## ✅ In 3 Schritten starten

### Schritt 1 — Datei finden
Such die Datei:

```
START_Sel01-Tweaker.bat
```

### Schritt 2 — Doppelklick
Mach einen **Doppelklick** drauf.

> Es kommt ein blaues Fenster von Windows: *"Möchten Sie zulassen, dass diese App
> Änderungen vornimmt?"* → Klick auf **JA**.
> (Das Programm braucht Admin-Rechte, um Windows zu ändern. Das ist normal.)

### Schritt 3 — Zahl wählen
Jetzt siehst du ein schwarzes Fenster mit einem Menü:

```
==========================================
          S E L 0 1 - T W E A K E R
     Windows 11 in 1 Klick optimieren
==========================================

  [1]  GAMING   - empfohlen
  [2]  CLEAN    - maximales Debloat
  [3]  TESTLAUF - zeigt nur an, aendert NICHTS
  [4]  RUECKGAENGIG - macht letzten Lauf weg
  [5]  Beenden

  Deine Wahl (1-5) und Enter:
```

- Tipp einfach **`1`** und drück **Enter**. (Das ist die beste Wahl für die meisten.)
- Dann **warten** — das Fenster NICHT schließen. Wenn unten **FERTIG** steht: erledigt.
- **Neustart** machen, damit alles greift.

**Das war's. Mehr ist nicht.** 🎉

---

## 🤔 Welche Zahl soll ich nehmen?

| Taste | Für wen? | Was passiert |
|------|----------|--------------|
| **1 GAMING** | Du zockst / normaler PC | Bestes für Spiele. Game Mode bleibt an. **Nimm das, wenn du unsicher bist.** |
| **2 CLEAN** | Office / kein Gaming | Räumt am gründlichsten auf, schaltet auch Spiele-Aufnahme komplett ab. |
| **3 TESTLAUF** | Erst gucken | Zeigt nur, *was* es machen würde. Ändert **gar nichts**. Gut zum Ausprobieren. |
| **4 RÜCKGÄNGIG** | Etwas gefällt nicht | Macht den letzten Durchlauf wieder weg. |

> 💡 **Angst? Mach erst `3` (Testlauf).** Da passiert nichts, du siehst nur die Liste.

---

## 🪟 Werden die Windows-Leistungs-Einstellungen automatisch gesetzt?

**Ja, automatisch.** Du kennst dieses Fenster?

```
Leistungsoptionen  ->  Visuelle Effekte  ->  ( ) Fuer optimale Leistung anpassen
```

Genau das stellt das Programm für dich ein — auf **"Benutzerdefiniert"**, alles
Unnötige aus, aber diese 3 bleiben **AN** (damit Windows trotzdem schön aussieht):

- ✔ Fensterinhalt beim Ziehen anzeigen
- ✔ Kanten der Bildschirmschriftarten verfeinern
- ✔ Miniaturansichten statt Symbolen

Du musst das **nicht** mehr von Hand klicken.

---

## ↩️ Etwas rückgängig machen

Falls dir etwas nicht passt: Doppelklick auf die `.bat`, dann **`4`** drücken.
Das stellt die geänderten Einstellungen wieder zurück.

**Wichtig:** Apps, die beim Aufräumen gelöscht wurden, kommen so **nicht** zurück —
die kannst du bei Bedarf neu aus dem **Microsoft Store** installieren.

Zusätzlich legt das Programm **vorher automatisch einen Windows-Wiederherstellungspunkt**
an. Im Notfall: Windows-Suche → *"Wiederherstellungspunkt erstellen"* →
*"Systemwiederherstellung..."* → den Punkt **"Sel01Tweaker - before optimization"** wählen.

---

## ❓ Häufige Fragen (FAQ)

**Ist das gefährlich?**
Vorher wird ein Wiederherstellungspunkt + eine Sicherung gemacht. Mit `4` kannst du
zurück. Trotzdem: bei einem brandneuen/Test-PC zuerst ausprobieren ist am sichersten.

**Brauche ich Internet?**
Für die ersten beiden Schritte (Debloat + KI entfernen) ja. Wenn kein Internet da
ist, überspringt es die und macht den Rest trotzdem.

**Wie lange dauert es?**
Meist ein paar Minuten. Fenster offen lassen, bis **FERTIG** kommt.

**Muss ich neu starten?**
Ja, danach einmal neu starten — dann sind alle Änderungen aktiv.

**Wo sehe ich, was gemacht wurde?**
Im Ordner `C:\ProgramData\Sel01Tweaker\` liegt eine Log-Datei und die Sicherung.

---

## 🆘 Wenn etwas nicht geht

- **Kein blaues "JA"-Fenster?** Rechtsklick auf die `.bat` → **"Als Administrator ausführen"**.
- **"Skript kann nicht geladen werden"?** Der Starter umgeht das normalerweise. Falls
  nicht: PowerShell als Admin öffnen und einmal
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ausführen.
- **Fenster schließt sofort?** Du hast die `.bat` evtl. ohne Admin gestartet — nimm
  Rechtsklick → "Als Administrator ausführen".
