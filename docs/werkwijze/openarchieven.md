# Open Archieven

Nederlandse basisregistratie-akten (geboorte, huwelijk, overlijden) en veel meer.

## Tools

| tool | kwaliteit | gebruik |
|---|---|---|
| `openarchieven_get_marriages(name1, name2)` | **goed** | huwelijksakten; geeft direct resultaat |
| `openarchieven_get_births(...)` / `get_deaths(...)` | goed | geboorte-/overlijdensakten |
| `openarchieven_search_records(name)` | goed | algemene zoekopdracht |
| `openarchieven_show_record(archive, identifier)` | goed | details van één akte |
| `openarchieven_match_record(name, birthyear)` | **matig** | matcht alleen bij exacte gegevens |
| `openarchieven_search_transcriptions` | **slecht** | full-text op handschriftherkenning — vooral ruis |

## Formaten

- IIIF-image: `https://images.memorix.nl/gra/iiif/{IMAGEID}/full/full/0/default.jpg`
- A2A-identifier: `{archive}:{uuid}`, bv. `gra:8d4a775c-2a8c-2817-1e7c-238dcd425554`

## Handige collecties

- **Memories van Successie** (±47.000 in Groningen) — kantoren Zuidbroek (1819–1855),
  Winschoten, Rayon Oldambt (1809–1813). Let op: de Rayon Oldambt-registers beslaan slechts
  **1806–1811**.
- **Boedelbeschrijving** (±18.000) — boedelinventarissen.

## Valkuilen

- **Successiememories staan vaak al in de boom.** Check eerst de notities voordat je ze als
  nieuwe vondst presenteert.
- **Getrouwde vrouwen** staan vaak onder hun meisjesnaam of patroniem; armen komen helemaal
  niet in de memories voor.
- **Niet alles is gedigitaliseerd**: veel overlijdensakten (vooral na 1877) ontbreken.
- Een memorie kan eindigen met een **negatief saldo** ("geen belasting") — dat is nog steeds
  een bruikbare bron, maar bevat soms weinig.
- Provinciale dekking verschilt. Sommige archieven (bv. Amsterdam) zitten **niet** in Open
  Archieven; gebruik daar de eigen beeldbank van het stadsarchief.
