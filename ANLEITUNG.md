# Sel01-Tweaker - Anleitung (fuer alle, ganz einfach)

Dieses Programm macht dein Windows 10 oder 11 schneller und sauberer, mit einem
Klick. Es entfernt Muell-Apps, Werbung, Telemetrie und Copilot, stellt die besten
Leistungs-Einstellungen ein und loescht Muell-Dateien (temporaere Dateien, alte
Update-Reste, Papierkorb). Am Arbeitsspeicher aendert es nichts mehr - darum
kuemmert sich Windows von allein besser.

Du musst nichts koennen und nichts einstellen. Doppelklick, fertig.

---

## In 3 Schritten starten

### Schritt 1: Datei finden
Such die Datei:

```
START_Sel01-Tweaker.bat
```

### Schritt 2: Doppelklick
Mach einen Doppelklick drauf.

Es kommt ein blaues Fenster von Windows ("Moechten Sie zulassen, dass diese App
Aenderungen vornimmt?"). Klick auf **JA**. Das Programm braucht Admin-Rechte, um
Windows zu aendern. Das ist normal.

### Schritt 3: Zahl waehlen
Jetzt siehst du ein schwarzes Fenster mit einem Menue:

```
==========================================
          S E L 0 1 - T W E A K E R
     Windows 10/11 in 1 Klick optimieren
==========================================

  [1] JETZT OPTIMIEREN  - empfohlen
  [2] NUR TESTEN        - zeigt nur, aendert NICHTS
  [3] MEHR / EXPERTE    - Clean, Reparatur, DNS, Rueckgaengig
  [4] BEENDEN

  Deine Wahl (1-4) und Enter:
```

Tipp einfach **1** und druck **Enter**. Vorher zeigt das Programm noch eine
Uebersicht, was es macht, und fragt einmal nach. Dann warten und das Fenster
nicht schliessen. Wenn unten **FERTIG** steht, ist es durch. Danach den PC neu
starten, damit alles greift.

Das war's.

---

## Welche Zahl soll ich nehmen?

| Taste | Fuer wen | Was passiert |
|------|----------|--------------|
| **1 Optimieren** | jeder, auch zum Zocken | Die normale Wahl. Macht den PC schneller und sauberer und laesst Game Mode an. Nimm das, wenn du unsicher bist. |
| **2 Nur testen** | erst gucken | Zeigt nur, was passieren wuerde. Aendert gar nichts. Gut zum Ausprobieren. |
| **3 Mehr / Experte** | fortgeschritten | Hier liegen Clean-Modus (gruendlicheres Aufraeumen fuer Office-PCs), Reparatur, DNS aendern und Rueckgaengig. |
| **4 Beenden** | - | Schliesst das Programm. |

Angst? Mach erst **2 (Nur testen)**. Da passiert nichts, du siehst nur die Liste.

---

## Werden die Windows-Leistungs-Einstellungen automatisch gesetzt?

Ja. Du kennst dieses Fenster?

```
Leistungsoptionen  ->  Visuelle Effekte  ->  ( ) Fuer optimale Leistung anpassen
```

Genau das stellt das Programm fuer dich ein, auf "Benutzerdefiniert", alles
Unnoetige aus. Diese drei bleiben aber an, damit Windows trotzdem gut aussieht:

- Fensterinhalt beim Ziehen anzeigen
- Kanten der Bildschirmschriftarten verfeinern
- Miniaturansichten statt Symbolen

Du musst das nicht mehr von Hand klicken.

---

## Etwas rueckgaengig machen

Doppelklick auf die `.bat`, dann **3 (Mehr / Experte)**, dann **Rueckgaengig**.
Das stellt die geaenderten Einstellungen wieder zurueck.

Apps, die beim Aufraeumen geloescht wurden, kommen so nicht zurueck. Die kannst
du bei Bedarf neu aus dem Microsoft Store installieren.

Zur Sicherheit legt das Programm vorher automatisch einen Windows-Wiederher-
stellungspunkt an. Im Notfall: Windows-Suche, "Wiederherstellungspunkt erstellen",
dann "Systemwiederherstellung..." und den Punkt "Sel01Tweaker - before
optimization" waehlen.

---

## Wichtig fuer alle, die eine aeltere Version hatten (bis 1.9)

Aeltere Versionen haben eine Aufgabe eingerichtet, die jede Stunde im Hintergrund
den Arbeitsspeicher "geleert" hat. Das war ein Fehler von uns. Windows musste
danach alles wieder muehsam von der Festplatte nachladen, und genau davon ist der
PC alle Stunde fuer ein paar Minuten eingefroren. In der Ereignisanzeige stand
dazu nichts, deshalb war es so schwer zu finden.

Diese Aufgabe gibt es nicht mehr. Du musst nichts machen: Beim naechsten Start
entfernt das Programm sie automatisch von deinem PC. Danach laeuft von uns nichts
mehr im Hintergrund.

Wer den Arbeitsspeicher trotzdem einmal aufraeumen will, startet das Programm mit
`-RamClean`. Das passiert dann genau einmal und nicht immer wieder.

---

## Haeufige Fragen

**Ist das gefaehrlich?**
Vorher wird ein Wiederherstellungspunkt und eine Sicherung gemacht, und du kannst
alles rueckgaengig machen. Auf einem brandneuen oder Test-PC zuerst ausprobieren
ist trotzdem am sichersten.

**Brauche ich Internet?**
Fuer die ersten beiden Schritte (Debloat und KI entfernen) ja. Ohne Internet
ueberspringt das Programm die und macht den Rest trotzdem.

**Wie lange dauert es?**
Meist ein paar Minuten. Fenster offen lassen, bis FERTIG kommt.

**Muss ich neu starten?**
Ja, danach einmal neu starten, dann sind alle Aenderungen aktiv.

**Wo sehe ich, was gemacht wurde?**
Im Ordner `C:\ProgramData\Sel01Tweaker\` liegt eine Log-Datei und die Sicherung.

---

## Wenn etwas nicht geht

- Kein blaues "JA"-Fenster? Rechtsklick auf die `.bat`, dann "Als Administrator
  ausfuehren".
- "Skript kann nicht geladen werden"? Der Starter umgeht das normalerweise. Falls
  nicht: PowerShell als Admin oeffnen und einmal
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ausfuehren.
- Fenster schliesst sofort? Du hast die `.bat` ohne Admin gestartet. Nimm
  Rechtsklick, "Als Administrator ausfuehren".
