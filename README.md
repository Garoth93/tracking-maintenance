# Upkeep — manutenzioni e scadenze dei tuoi oggetti (iOS)

App iOS nativa (Swift + SwiftUI, grafica Material 3) per tenere il registro di
auto, moto, bici, sci, gomme, caldaia e qualunque oggetto abbia bisogno di
manutenzioni o scadenze. Sviluppata senza Mac: compilata da GitHub Actions e
installata sull'iPhone con un account Apple gratuito tramite Sideloadly o SideStore.

[![build-ipa](https://github.com/Garoth93/tracking-maintenance/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/Garoth93/tracking-maintenance/actions/workflows/build-ipa.yml)
[![test-linux](https://github.com/Garoth93/tracking-maintenance/actions/workflows/test-linux.yml/badge.svg)](https://github.com/Garoth93/tracking-maintenance/actions/workflows/test-linux.yml)

## Cosa fa

- **Oggetti** di qualunque tipo, con contatore (km, uscite, ore…) aggiornabile in un tocco,
  campi personalizzati (targa, modello, misura gomme, DOT…), icona e colore.
- **Operazioni** per categoria: Tagliando, Cambio olio, Revisione, Assicurazione, Bollo,
  Cambio gomme, Sciolinatura, Affilatura lamine, Pulizia catena… con data, contatore,
  costo, note e campi propri (officina, compagnia, litri…).
- **Scadenze** solo dove servono: intervallo in mesi e/o contatore (es. tagliando ogni
  12 mesi o 15.000 km) oppure data impostata a mano (es. scadenza dell'assicurazione).
  Stato *in regola / a breve / scaduta*, barra di avanzamento e **stima della data**
  dai km medi. Promemoria con **notifiche locali**.
- **Componenti montabili**: le gomme (o le ruote della bici) sono oggetti a sé. Montale
  sull'auto: accumulano i km dell'auto finché restano montate. Montando le invernali
  le estive vengono smontate automaticamente; ognuna ha i suoi km e il suo storico.
- **Storico** per anno (operazioni, letture del contatore, montaggi) e **spese** per
  anno, mese, oggetto e tipo di operazione, con €/km.
- **Tutto parametrizzabile** dalle Opzioni: tipi di oggetto (unità, campi, componente
  sì/no) e tipi di operazione (a quali oggetti si applicano, intervallo, campi).
- Tema chiaro/scuro, colore principale a scelta (palette Material generata dal colore),
  backup/ripristino JSON ed export CSV delle operazioni.

Al primo avvio l'app è vuota con i tipi predefiniti; dalla home puoi caricare i
**dati di esempio** (auto con gomme estive/invernali, bici, sci, caldaia) per provarla.

## Struttura

```
apps/Upkeep/          app SwiftUI (project.yml per XcodeGen, Sources/, Resources/)
packages/UpkeepCore/  logica non grafica, testata con `swift test` anche su Linux
.github/workflows/    build-simulator, build-ipa, test-linux
CLAUDE.md             convenzioni e regole di lavoro per Claude Code
```

## Installare l'app sull'iPhone

### 1. Scaricare il `.ipa`

1. Pagina **Actions** della repo → workflow **build-ipa**.
2. Apri l'ultimo run verde (o avvialo con **Run workflow**).
3. In fondo alla pagina, sezione **Artifacts**, scarica `Upkeep-unsigned-ipa`
   (uno zip che contiene `Upkeep-unsigned.ipa`) ed estrailo. Resta disponibile 30 giorni.

### 2. Firmare e installare con Sideloadly

1. Collega l'iPhone via USB, sbloccalo e scegli "Autorizza".
2. Apri Sideloadly, trascina `Upkeep-unsigned.ipa` nella finestra.
3. Inserisci il tuo Apple ID (account gratuito) e premi **Start**.
4. Sull'iPhone: Impostazioni → Generali → **VPN e gestione dispositivo** → il tuo
   Apple ID → **Autorizza**. Serve anche la **Modalità sviluppatore** attiva
   (Impostazioni → Privacy e sicurezza).

### 3. Limiti dell'account gratuito

- La firma scade dopo **7 giorni**: rifirma lo stesso `.ipa` con Sideloadly (i dati restano,
  il bundle ID `com.garoth93.upkeep` non cambia). SideStore può rifirmare dal telefono.
- Massimo 3 app firmate contemporaneamente per Apple ID.
- Le notifiche **locali** (promemoria scadenze) funzionano; iCloud no.
- I dati stanno nella sandbox dell'app: **si perdono se elimini l'app**. Usa
  Opzioni → *Backup JSON* ogni tanto.
