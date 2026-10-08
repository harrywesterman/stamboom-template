# webtrees: records wijzigen

De schrijftools komen uit de webtrees-MCP (`webtrees_mcp-server_*`). Elke wijziging komt
in de **goedkeuringswachtrij**: `get-record` blijft de oude versie tonen tot een moderator
goedkeurt. Herhaal nooit blind dezelfde write; controleer eerst het ontvangstbewijs.

Contract gecontroleerd tegen [webtrees-API `119809d`](https://github.com/harrywesterman/webtrees-API/commit/119809d)
(8 oktober 2026). De lokale bridge volgt `master`; de PHP-module op de webtrees-server
moet deze versie eveneens ondersteunen.

## `modify-record`

In de standaardmodus vervangt `modify-record` het hele GEDCOM-record, maar
**beschermde links blijven behouden**:
bestaande `FAMS`/`FAMC`/`OBJE`/`CHIL` verdwijnen niet meer stilzwijgend.

- Weglaten uit de nieuwe GEDCOM = link blijft staan.
- Echt verwijderen: `remove-protected-links=true`.
- Toevoegen: `mode=merge` met complete feitblokken, bijvoorbeeld `1 OCCU Timmerman`.
  Dit behoudt bestaande feiten en gebruikt de nieuwste pending versie. Exact gelijke
  blokken worden niet verdubbeld; bestaande feiten of geneste citaten worden niet vervangen.
- Vervangen: standaardmodus met het volledige record; beoordeel bestaande pending changes
  eerst.
- Preview zonder pending change: `dry-run=true`; toont alle toegevoegde/verwijderde
  feitblokken, inclusief naam-subtags en broncitaten.
- Het antwoord rapporteert `preserved-links` en `removed-links`.

Bekijk de voorgenomen wijziging met `dry-run`. Verifieer na schrijven met `verify-write`
en de SHA-256 `hash`/`version` uit het schrijf-antwoord.

## Bronnen en citaten

- `create-source` — eerste-klas `SOUR`-record (titel, auteur, publicatie, note).
- `modify-source` — bronvelden bijwerken zonder de rest van het GEDCOM-record te raken.
- `get-sources` — bronrecords in een boom opsommen.
- Bij meerdere `TITL`, `AUTH`, `PUBL` of `NOTE`-velden weigert `modify-source` een
  ambiguë vervanging met 409; bewerk die bron handmatig.
- `add-source-citation` — één of meer bronnen koppelen aan een INDI/FAM-record of specifieke
  gebeurtenissen. Een ontbrekende gebeurtenis geeft 404. Geef
  `citations: [{source-xref, event, page, note}, …]` mee voor één pending change; `dry-run=true` om te previewen. Dubbele links zijn no-ops.
- `get-citations` — bestaande citaten lezen (gebeurtenis, pagina, note).

## Personen en gezinnen

- `add-child-to-family` maakt een **nieuw** kind. Een `CHIL`-regel naar een bestaand persoon
  wordt geweigerd (geen spookkind) — gebruik daarvoor `link-child-to-family`.
- `link-child-to-family`, `link-spouse-to-individual`, `add-spouse-to-individual`,
  `add-parent-to-individual` koppelen bestaande records.
- `add-family` maakt partners, kinderen, alle `FAMS`/`FAMC`/`CHIL`-links en gezinsnotities
  in één transactie. Geef **XREF's**, geen losse namen. Bewaar een `idempotency-key`
  voor veilige herhaling van dezelfde payload.
- `create-records` maakt 1–100 records atomair met lokale IDs voor onderlinge verwijzingen.
  Neem wederzijdse gezinslinks expliciet op. Ontbrekende of ontoegankelijke externe
  verwijzingen worden afgewezen. Een sleutel met gewijzigde payload geeft 409.
  De indiening is atomair, de goedkeuring blijft per record.

## Pending changes

- `list-pending-changes` — pagineert (`limit`/`offset`, default 100/max 500), `summary=true`
  laat de GEDCOM-payloads weg; de respons bevat `total`.
- `get-pending-record` — de pending GEDCOM voor één record.
- `cancel-pending` — een pending change intrekken. Een ingetrokken **creatie** laat een gat
  in de xref-reeks: leid nooit ontbrekende records af uit gaten.
- `cancelled-xrefs` leest bewaarde afgewezen creaties (member-read-scope én boombeheerrechten).
  Volg `next-offset`; `history-complete=false` betekent dat gewiste historie en andere
  gaten niet gereconstrueerd kunnen worden. Actieve/hergebruikte XREF's zijn uitgesloten.
- `verify-write` — status `pending`/`applied`/`pending_delete`/`deleted`; geef de hash mee
  als `hash` of `version` (aliassen) en eis `matches=true`. Weglaten geeft `matches=null`
  en bevestigt geen write. `pending` betekent opgeslagen, maar nog niet goedgekeurd.
- Alle GEDCOM-writes geven gelijke SHA-256-waarden in `hash` en `version`. Bij meerdere
  records bevat `records` per record een eigen ontvangstbewijs: verifieer elk afzonderlijk.
  Staging van media geeft pas hashes wanneer de PUT records heeft geschreven.
- Media-writes en merge behouden de nieuwste pending feiten/links. Een verouderde snapshot
  geeft 409 zonder write, met waar beschikbaar `change-id` en `xref`; herlaad en controleer
  de eerdere write. Pending verwijderingen en private feiten kunnen wijzigingen blokkeren.

## Foutcodes

Foutresponsen gebruiken `error.code` (de lokale bridge behoudt die): o.a. `token_invalid`,
`scope_missing`, `pending_conflict`, `protected_links_would_be_removed` en
`inline_upload_too_large`.

De **403**-set is fijnmaziger: `record_privacy_denied` (privacy-instelling),
`record_access_denied` (geen toegang tot het record), `scope_missing` (ontbrekende
scope/media-rechten) en anders `access_denied`. Een expliciete `code:`-prefix in de melding
wordt overgenomen. Fouten van webtrees zelf worden nu ongewijzigd doorgegeven (code +
message) in plaats van vervangen door een algemene melding.

## Zoeken en leesrechten

`search-structured` zoekt op naam, plaats, jaarbereik, beroep of tekst in NOTE/bronvelden,
met stabiele `offset`/`limit`-paginering en sortering op boom/XREF. Lees daarna nog steeds
het volledige persoon- en gezinsrecord voordat je iets nieuw noemt.

MCP-lezen is standaard privacy-gefilterd. De optionele scope `mcp_read_member` moet
expliciet worden ingeschakeld en gebruikt alleen de rechten van de technische gebruiker;
`api_read_member` op hetzelfde token verleent geen MCP-memberrechten.
