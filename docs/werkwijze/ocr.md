# OCR van oude handschriften (kraken + ARletta)

Voor 17e–19e-eeuwse Nederlandse aktes, kerkregisters en brieven.

```bash
./bin/ocr-handschrift.sh <scan.png|jpg|tif> [output.txt]
```

## Wat het doet

- Upscalet lage-resolutie scans (kraken werkt beter op ~300 dpi / ≥2500 px breed).
- Gebruikt **geen binarisatie**.
- Draait `segment -bl -i blla.mlmodel ocr -m super.mlmodel`.

## Modellen

| model | functie |
|---|---|
| `super.mlmodel` (16 MB) | herkenning — getraind op VOC (17e–18e eeuw), notariële akten (19e eeuw) en Antwerpse politierapporten (~92% character accuracy) |
| `blla.mlmodel` (5 MB) | baseline/regel-segmentatie |

Ze staan in `${OCR_MODELS:-$HOME/ocr-models}/ARletta/models/`. `setup.sh` haalt ze op uit de
Zenodo-zip (record 11191457) — alleen de twee modellen (~21 MB), niet de 8,5 GB zip.
Er zijn meer modellen in de zip (o.a. `notarial`, `voc`, `manu`, `antw-*`); haal die op met
`python3 bin/download-arletta-models.py --all`.

## CRITICAL: niet binariseren

Kraken's `binarize`-stap vernietigt lage-contrast scans (wordt 99% wit → **0 regels
gedetecteerd**). Sla binarisatie altijd over en laat kraken direct op RGB/grijs segmenteren.

## Python-versie

Kraken werkt **niet op Python 3.14**. De venv wordt gemaakt met **Python 3.13** via `uv`:

```bash
uv venv --python 3.13 "$OCR_MODELS/.venv-kraken"
uv pip install --python "$OCR_MODELS/.venv-kraken/bin/python" kraken
```

## Beperkingen

- Goed op 17e–19e-eeuws administratief/notarieel schrift: namen, datums en plaatsen komen er
  meestal leesbaar uit, **met OCR-ruis**.
- **Niet** getraind op Kurrent/Sütterlin (Duits handschrift). Gebruik daarvoor een
  Kurrent-model (bv. `dh-unibe/trocr-kurrent` op HuggingFace).
- CPU-only is ~26–42 regels per 12–30 s — prima voor losse aktes.
- Upscalen en segmenteren zijn de zwakke schakels; controleer de regels altijd tegen het
  origineel voordat je data overneemt.

## Tips

- Knip grote scans eerst in stukken (`magick scan.png -crop WxH+X+Y +repage deel.png`).
- Vergelijk de OCR-tekst altijd met de afbeelding; het model "leest" en kan plausibel klinken
  terwijl het fout is.
