# webtrees: media

Alles met afbeeldingen/media gaat via de **webtrees-MCP** — niet via de browser en niet via
handgemaakte URL's. Eén ding gaat bewust buiten de MCP: de **bytes** ophalen (volledige
resolutie), want de MCP geeft alleen metadata.

## 1. Media-XREF vinden

```
webtrees_mcp-server_get-record(tree='{{TREE}}', xref='I1', format='gedcom')
```

Regels als `1 OBJE @X13016@` geven de media-XREF. De bestandsnaam staat in het mediarecord:

```
0 @X13016@ OBJE
1 FILE Huwelijk … 1781.png
```

**Let op:** huwelijksakten hangen vaak aan het **F-record** (gezin), niet aan de I-records.
Check dus altijd beide.

## 2. Metadata en bytes

1. `webtrees_mcp-server_get-media(tree, xref)` → `filename` (het **volledige relatieve
   opslagpad**, bv. `api-media/ab12…/naam.png`), `title`, `url`, `pending`.
2. Bytes op volledige resolutie via de authenticated downloadroute (URL-encode de `filename`):

```bash
curl -sS -H "Authorization: Bearer $TOKEN" -o /tmp/scan.png \
  "{{WEBTREES_URL}}/api/media/download?tree={{TREE}}&xref=X13016&filename=api-media%2Fab12...%2Fnaam.png"
```

3. Lees het bestand met de `read`-tool om het echt te bekijken. Het model kan oud
   handschrift, Kurrent/Sütterlin en historische kaarten lezen.

De mediapagina toont alleen een **thumbnail** (~400 px); de download geeft volledige
resolutie (vaak 2000–4000+ px breed). Voor lange documenten: knip de afbeelding in stukken
met ImageMagick (`magick scan.png -crop WxH+X+Y +repage deel.jpg`) en bekijk de delen apart.

## 3. Uploaden

- **≤ 512 KiB** → `upload-media` met inline base64 (`content-base64`). Verzin **nooit** bytes:
  lees het bestand en codeer het (`base64 -i bestand.jpg`), verifieer desnoods met
  `shasum -a 256`.
- **> 512 KiB t/m 20 MiB** → `upload-media-chunk`:
  - per chunk: `upload-id` (8 hex Unix-timestamp + 24 random hex = 32 hex), `offset`,
    `total-bytes`, `sha256` (van het **hele** bestand), `final`, en `content-base64`
    van max. **256 KiB gedecodeerd** (262.144 bytes);
  - de metadata (`tree`, `target-xref`, `target-type`, `filename`, `title`) moet bij **élke**
    chunk identiek zijn;
  - de laatste chunk (`final: true`) verifieert de SHA-256 en maakt het pending mediarecord
    + de koppeling aan;
  - exacte chunk-retries en exacte final-replay zijn veilig (idempotent); een sessie verloopt
    1 uur na de `upload-id`-timestamp;
  - de eerste call begint op `offset: 0`; `next-offset` in het antwoord bevestigt de
    opgeslagen bytes;
  - bij een **onzekere commit (409)**: verifiëren met een beheerder en **niet** opnieuw
    proberen met een nieuw ID.
- Te grote inline base64 → nette **413**: `inline_upload_too_large`,
  `maxInlineBytes: 524288`, `multipartEndpoint: /api/media`, `requiredScope: api_write`.
- Toegestaan: JPEG, PNG, GIF, WebP; MIME-type moet bij de extensie passen; max. 20 MiB en
  40 megapixels; veilige bestandsnaam (geen pad); geen SVG/PDF of corrupte bestanden.

**Compatibiliteits-fallback** (meestal niet nodig): authenticated REST `POST /api/media`
(multipart: `tree`, `target-xref`, `target-type`, `title`, `date`, `file`).

## 4. Koppelen, ontkoppelen, bijwerken, verwijderen

`link-media` (target-type `INDI`/`FAM`/`SOUR`), `unlink-media`, `update-media`,
`delete-media`.

## Valkuilen

- **Max. één media-write per record per pending-periode.** Een tweede poging geeft HTTP
  **409** ("Record has pending changes") tot een moderator de eerste heeft goedgekeurd.
  De 409 gaat vóór de groottevalidatie.
- **`curl -F "note=…"` kapt af bij de eerste `;`** (puntkomma wordt als parameter-scheiding
  gezien). Gebruik geen `;` in `-F note=...`, of zet de volledige tekst later via
  `update-media`.
- Een privacy-only read kan tijdelijk **404** geven tot goedkeuring; bewaar de upload-XREF
  en upload **niet** opnieuw.
