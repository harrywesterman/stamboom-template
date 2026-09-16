# Delpher (kranten, KB)

Delpher is de Nederlandse krantendatabase van de KB. Gebruik de MCP-tools
`newspapers_search_newspapers` en `newspapers_newspapers_get_snippet`.

## CRITICAL: query-syntax

```
newspapers_search_newspapers(source='delpher', query='Westerman PROX Heiligerlee')
```

- **Twee termen:** gebruik **PROX** (proximity).
- **Multi-woord zónder PROX levert 0 resultaten:** `Westerman Heiligerlee` → 0,
  `"Westerman" Heiligerlee` → 0.
- **Eén woord** werkt wel, maar is vaak te ruisig (`Westerman` → 104.000 hits).

Als een zoekopdracht 0 geeft: probeer eerst PROX voordat je concludeert dat er niets is.

## Parameters

| parameter | toelichting |
|---|---|
| `query` | PROX (`naam1 PROX naam2`) of één woord |
| `source` | `'delpher'` of `'all'` |
| `date_from` / `date_to` | `YYYY-MM-DD` |
| `page`, `rows` | paginering (max. 20 per pagina) |

## Wat wel en niet werkt

- **Werkt:** achternaam + plaatsnaam met PROX (`Westerman PROX Scheemda`) — levert
  Winschoter courant, Nieuwe Provinciale Groninger Courant e.d.
- **Werkt half:** algemene familienamen — overladen met bekende naamgenoten.
- **Werkt niet:** OCR is onbetrouwbaar voor kleine dorpsfiguren. Veel arbeiders en kleine
  boeren komen niet in de krant. **Geen hit betekent niet "bestaat niet".**
- **Regionale dekking verschilt per periode.** Sommige kranten zijn voor bepaalde jaren niet
  gedigitaliseerd (bv. de Winschoter courant rond 1988–1989). Vermeld dat als beperking.

## Uitsnedes maken

- ALTO-XML met woordcoördinaten: `https://resolver.kb.nl/resolve?urn=<page>:alto`
- Volledige pagina (JP2): `https://resolver.kb.nl/resolve?urn=<page>:image`
- Snijd met ImageMagick: `magick page.jp2 -crop WxH+X+Y +repage out.jpg`
- De `<page>`-urn is `ddd:…:mpeg21:pNNN` (3 cijfers) of `MMRHCG04:…:mpeg21:p000NN`
  (5 cijfers).
- Document-id-formaat (zonder `ddd:`-prefix): `MMRHCG03:163500031:mpeg21:a00037`.
- `get_snippet` verwacht per bron een ander `document_id`/`snippet_coords`-formaat.

## Viewer-uitlezen (Playwright)

- OCR-tekst: `.right-panel.object-viewer__ocr-panel`
- `&ort=tekst` in de URL schakelt naar tekstweergave.
- Delpher pagineert artikelen met "Volgend resultaat" — vaak meerdere artikelen op één pagina.

## Rate limits

Delpher rate-limit IP bij veel requests (HTTP 429). Doe het rustig en pauzeer.
