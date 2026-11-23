# redmine_gtt_uldk

A [Redmine](https://www.redmine.org) plugin for [redmine_gtt](https://github.com/gtt-project/redmine_gtt)
that fills the issue geometry with **Polish cadastral parcel boundaries** fetched from the
[ULDK](https://uldk.gugik.gov.pl) service of GUGiK (Usługa Lokalizacji Działek Katastralnych),
based on the commune / precinct / parcel number stored in issue custom fields.

Useful for land surveying offices, municipalities and anyone who tracks work per land parcel:
type the parcel number, save the issue, and the parcel appears on the GTT map.

*Polski opis poniżej.*

## Features

- Automatic: when an issue is saved with changed parcel fields (or without a geometry),
  the geometry is fetched **in the background** (ActiveJob) — saving never waits for ULDK.
- A geometry drawn by the user in the same edit is never overwritten.
- Several parcels in one field (`12/3, 12/4`, `dz. 5 i 7`) are merged into one geometry.
- A full ULDK parcel id (`046101_1.0001.12/3`) can be typed directly into the parcel field.
- Optional **registration unit map**: for listed communes a numeric precinct is resolved
  directly (`<unit>.<precinct>.<number>`) — faster and unambiguous.
- Ambiguous results are never guessed: only a single matching parcel is used.
- "Fetch parcel geometry from ULDK" link on the issue page for a manual refresh.
- Rake task to fill the geometry of existing issues, with a dry-run mode.
- English and Polish UI.

## Requirements

- Redmine 6.0 or newer (tested with Redmine 7.0)
- redmine_gtt 6.0 or newer (tested with 7.1) on PostgreSQL/PostGIS
- Outbound HTTPS access from the Redmine server to `uldk.gugik.gov.pl`
- Issue custom fields (text) for the commune, precinct and parcel number

## Installation

```sh
cd /path/to/redmine/plugins
git clone https://github.com/arielszeloch/redmine_gtt_uldk.git
# no gems, no migrations; restart Redmine
```

For the official Docker image, copy the directory into `/usr/src/redmine/plugins/`.

## Configuration

*Administration → Plugins → GTT ULDK parcels → Configure*

| Setting | Description |
|---|---|
| Commune / Precinct / Parcel number field | Issue custom fields to read. *Automatic* picks a field named `Gmina`, `Obręb` and `Nr działki` (case-insensitive). |
| Registration units | Optional, one line per unit: `commune names = TERYT unit id`, e.g. `Bydgoszcz, M. Bydgoszcz, MB = 046101_1`. Names are compared without case, diacritics, dots and spaces. The unit id is the part before the first dot of a parcel id (visible e.g. on geoportal.gov.pl). |
| Fetch geometry automatically | Background geocoding on issue save (on by default). |
| Max parcels per issue | Upper limit of parcel numbers taken from one issue (default 20). |

The plugin acts only in projects with the **GTT** module enabled.
The manual link is shown to users who can edit the issue.

### How a parcel is looked up

1. A full ULDK id in the parcel field → `GetParcelById`.
2. Commune listed in *Registration units* and a numeric precinct →
   `GetParcelById <unit>.<precinct, 4 digits>.<number>`.
3. Otherwise `GetParcelByIdOrNr "<precinct> <number>"`; when ULDK returns several parcels,
   they are narrowed down by the unit (if the commune is in the map) or by commune name.

Only an unambiguous single result is used; otherwise the parcel is reported as not found
(in the log for automatic runs, as a flash message for the manual link).

## Filling existing issues

```sh
# inside the Redmine directory
bundle exec rake redmine:gtt_uldk:backfill DRY_RUN=1 LIMIT=50   # preview, stores nothing
bundle exec rake redmine:gtt_uldk:backfill PROJECT=my-project    # fill issues without geometry
```

Options: `PROJECT` (identifier), `LIMIT`, `DRY_RUN=1`, `DELAY` (seconds between issues,
default 0.35 — please be gentle with the public service). Only issues without a geometry
and with a parcel number are processed. Updating the geometry does not create journal entries
or notifications.

With the official Docker image, prefix the command with
`SECRET_KEY_BASE=$REDMINE_SECRET_KEY_BASE` if the key is passed that way.

## Logging

Each automatic lookup logs one line, e.g.
`[ULDK] issue #123: ok 046101_1.0262.1/16` or `[ULDK] issue #124: not_found not found: 281/28`.

## Tests

The text helpers and the ULDK response parser have standalone tests (no Redmine needed):

```sh
ruby -Ilib test/unit/text_test.rb
```

## Notes

- ULDK is a free public service run by GUGiK; availability and data are its responsibility.
  Data comes from the land and building registers (EGiB) of the counties and may be outdated.
- Geometries are stored in EPSG:4326 as 3D, like redmine_gtt does.

## License

GPL-2.0, see [LICENSE](LICENSE).

---

## Po polsku

Plugin do Redmine dla [redmine_gtt](https://github.com/gtt-project/redmine_gtt), który na
podstawie pól zgłoszenia (gmina, obręb, numer działki) pobiera granice działek ewidencyjnych
z usługi [ULDK](https://uldk.gugik.gov.pl) GUGiK i zapisuje je jako geometrię zgłoszenia na mapie GTT.

**Jak działa**

- Po zapisaniu zgłoszenia ze zmienionymi polami działki (albo bez geometrii) geometria jest
  pobierana w tle — zapis nie czeka na ULDK.
- Geometria narysowana ręcznie w tej samej edycji nie jest nadpisywana.
- Kilka numerów w jednym polu (`12/3, 12/4`, `dz. 5 i 7`) daje jedną, połączoną geometrię.
- W polu numeru działki można wpisać pełny identyfikator (`046101_1.0001.12/3`).
- Opcjonalna lista **jednostek ewidencyjnych**: dla wskazanych gmin obręb podany numerem jest
  wyszukiwany bezpośrednio — szybciej i jednoznacznie. Przykład:
  `Bydgoszcz, M. Bydgoszcz, MB = 046101_1`.
- Niejednoznaczne wyniki nie są zgadywane — używana jest tylko pojedyncza pasująca działka.
- Na stronie zgłoszenia link **„Pobierz geometrię działek z ULDK”** do ręcznego odświeżenia.
- Zadanie rake `redmine:gtt_uldk:backfill` uzupełnia geometrię istniejących zgłoszeń
  (`DRY_RUN=1` — tylko podgląd).

**Instalacja:** skopiuj katalog do `plugins/` i zrestartuj Redmine (bez gemów i migracji).
Ustawienia: *Administracja → Pluginy → GTT ULDK parcels → Konfiguruj*. Plugin działa tylko
w projektach z włączonym modułem GTT. Domyślnie używa pól o nazwach `Gmina`, `Obręb`
i `Nr działki`.
