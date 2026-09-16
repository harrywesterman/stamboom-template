# nl-gov (Nederlandse overheidsdata)

Brede verzameling openbare overheidsbronnen. Voor genealogie zijn vooral deze bruikbaar.

## Genealogisch relevant

| bron | waarvoor |
|---|---|
| **BAG** (`bag_lookup_address`, `bag_address_detail`) | adressen, bouwjaar, oppervlakte, gebruiksdoel — om een woonadres te duiden |
| **BRK** (`brk_kadastrale_kaart_search`) | kadastrale percelen (bbox, EPSG:28992) |
| **PDOK** (`pdok_search`) | adressen en locaties |
| **CBS** (`cbs_*`) | historische/statistische cijfers per gemeente |
| **Rechtspraak** (`rechtspraak_search_ecli`) | uitspraken (ECLI) |
| **Open Raadsinformatie** (`ori_search`) | gemeenteraadsstukken |
| **Officiële bekendmakingen** | gemeenteblad, Staatscourant |
| **Bestuurlijke gebieden** | gemeente-indeling (nuttig bij grenswijzigingen) |

## Niet-genealogisch, maar beschikbaar

KNMI, NS-reisinformatie, NDW, Rijkswaterstaat, Eurostat, EUR-Lex, Tweede Kamer,
TenderNed, DUO, RIVM, Luchtmeetnet, verkiezingsuitslagen, Rijksbegroting.

## Let op

- Verschillende bronnen vereisen een **API-key** (o.a. KNMI, NS, DNB, EP-Online, DSO,
  Overheid API-register). Zonder key krijg je een nette foutmelding met een verwijzing naar
  de key. Zet zulke keys in `~/.config/stamboom/secrets.env`.
- Coördinaten: RD New **EPSG:28992** voor BAG/BRK; `bbox` is verplicht bij
  `brk_kadastrale_kaart_search`.
- Grenswijzigingen: gebruik `bestuurlijke_gebieden_search` om te zien onder welke gemeente een
  plaats in een bepaalde periode viel — belangrijk voor het duiden van akten.
