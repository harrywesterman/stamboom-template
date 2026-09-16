#!/usr/bin/env bash
# OCR van oude Nederlandse handschriften met kraken + ARletta (super model).
#
#   ./bin/ocr-handschrift.sh <scan.png|scan.jpg|scan.tif> [output.txt]
#
# Werkt op aktes, kerkregisters, brieven e.d. (17e-19e eeuw).
# - Upscalet lage-resolutie scans (kraken werkt beter op ~300dpi)
# - Gebruikt GEEN binarisatie (die vernietigt lage-contrast scans)
# - Modellen: ARletta super.mlmodel (herkenning) + blla.mlmodel (segmentatie)
#
# Omgevingsvariabelen: KRAKEN_VENV, OCR_MODELS (zie bin/_common.sh).

set -euo pipefail
# shellcheck source=bin/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Forceer CPU: de torch cu130-build mist kernels voor oudere GPU's (bv. sm_61 /
# GTX 1050) waardoor segmenteren faalt. Zet CUDA_VISIBLE_DEVICES=0 om de GPU te
# gebruiken op een ondersteunde kaart.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES-}"

MODELS="$OCR_MODELS/ARletta/models"
PYTHON="$KRAKEN_VENV/bin/python"
KRAKEN="$KRAKEN_VENV/bin/kraken"

if [ $# -lt 1 ]; then
    printf 'Gebruik: %s <scan.png|jpg|tif> [output.txt]\n' "$0"
    exit 1
fi

if [ ! -x "$KRAKEN" ]; then
    die "kraken niet gevonden in $KRAKEN_VENV — draai ./setup.sh"
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}-ocr.txt}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

[ -f "$INPUT" ] || die "bestand '$INPUT' bestaat niet"

if [ ! -f "$MODELS/super.mlmodel" ] || [ ! -f "$MODELS/blla.mlmodel" ]; then
    die "modellen niet gevonden in $MODELS — draai ./setup.sh"
fi

# Upscale naar ~300dpi als de afbeelding klein is (<2500px breed).
WIDTH="$("$PYTHON" -c "from PIL import Image; print(Image.open('$INPUT').width)")"
TARGET="$INPUT"
if [ "$WIDTH" -lt 2500 ]; then
    SCALE="$(python3 -c "print(max(1, round(3000/$WIDTH)))")"
    "$PYTHON" -c "
from PIL import Image
im = Image.open('$INPUT').convert('L')
scale = $SCALE
im = im.resize((im.width*scale, im.height*scale), Image.LANCZOS)
im.save('$TMPDIR/upscaled.png')
"
    TARGET="$TMPDIR/upscaled.png"
    ok "upscaled ($WIDTH -> $("$PYTHON" -c "from PIL import Image; print(Image.open('$TMPDIR/upscaled.png').width)") px)"
fi

log "OCR: $INPUT"
"$KRAKEN" -i "$TARGET" "$OUTPUT" segment -bl -i "$MODELS/blla.mlmodel" ocr -m "$MODELS/super.mlmodel" 2>&1 \
    | grep -E "Segmenting|Processing|Writing|Error" || true

printf '\nKlaar: %s (%s regels)\n' "$OUTPUT" "$(wc -l < "$OUTPUT" | tr -d ' ')"
