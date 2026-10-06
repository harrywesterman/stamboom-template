# webtrees: records wijzigen (webtrees-API ≥ #14)

De schrijftools komen uit de webtrees-MCP (`webtrees_mcp-server_*`). Elke wijziging komt
in de **goedkeuringswachtrij**: `get-record` blijft de oude versie tonen tot een moderator
goedkeurt. Nooit twee keer dezelfde write op één record doen.

## `modify-record`

`modify-record` vervangt het hele GEDCOM-record, maar **beschermde links blijven behouden**:
bestaande `FAMS`/`FAMC`/`OBJE`/`CHIL` verdwijnen niet meer stilzwijgend.

- Weglaten uit de nieuwe GEDCOM = link blijft staan.
- Echt verwijderen: `remove-protected-links=true`.
- Preview zonder pending change: `dry-run=true`.
- Het antwoord rapporteert `preserved-links` en `removed-links`.

Verifieer de uitkomst met `dry-run` of `verify-write` (SHA-256 `hash`/`version` uit het
schrijf-antwoord).

## Bronnen en citaten

- `create-source` — eerste-klas `SOUR`-record (titel, auteur, publicatie, note).
- `modify-source` — bronvelden bijwerken zonder de rest van het GEDCOM-record te raken.
- `get-sources` — bronrecords in een boom opsommen.
- `add-source-citation` — één of meer bronnen koppelen aan een INDI/FAM-record of specifieke
  gebeurtenissen. Geef `citations: [{source-xref, event, page, note}, …]` mee voor één
  pending change; `dry-run=true` om te previewen. Dubbele links zijn no-ops.
- `get-citations` — bestaande citaten lezen (gebeurtenis, pagina, note).

## Personen en gezinnen

- `add-child-to-family` maakt een **nieuw** kind. Een `CHIL`-regel naar een bestaand persoon
  wordt geweigerd (geen spookkind) — gebruik daarvoor `link-child-to-family`.
- `link-child-to-family`, `link-spouse-to-individual`, `add-spouse-to-individual`,
  `add-parent-to-individual` koppelen bestaande records.
- `add-family` maakt partners, kinderen, alle `FAMS`/`FAMC`/`CHIL`-links en gezinsnotities
  in één transactie. Geef **XREF's**, geen losse namen.

## Pending changes

- `list-pending-changes` — pagineert (`limit`/`offset`, default 100/max 500), `summary=true`
  laat de GEDCOM-payloads weg; de respons bevat `total`.
- `get-pending-record` — de pending GEDCOM voor één record.
- `cancel-pending` — een pending change intrekken. Een ingetrokken **creatie** laat een gat
  in de xref-reeks: het xref wordt niet hergebruikt of getombstoned, dus leid nooit
  ontbrekende records af uit gaten.
- `verify-write` — status `pending`/`applied`/`pending_delete`/`deleted`; geef de hash mee
  als `hash` of `version` (aliassen). Weglaten leest alleen de huidige staat.

## Foutcodes

Foutresponsen gebruiken `error.code` (de lokale bridge behoudt die): o.a. `token_invalid`,
`scope_missing`, `pending_conflict`, `protected_links_would_be_removed` en
`inline_upload_too_large`.

De **403**-set is fijnmaziger: `record_privacy_denied` (privacy-instelling),
`record_access_denied` (geen toegang tot het record), `scope_missing` (ontbrekende
scope/media-rechten) en anders `access_denied`. Een expliciete `code:`-prefix in de melding
wordt overgenomen. Fouten van webtrees zelf worden nu ongewijzigd doorgegeven (code +
message) in plaats van vervangen door een algemene melding.
