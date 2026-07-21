#!/bin/bash
mkdir -p data/svg  # Create the output directory if it doesn't exist
for pdf in data/pdf/*.pdf; do
  # Use basename to strip the directory part and suffix
  base=$(basename "$pdf" .pdf)
  # Export to SVG in the data/svg directory
  inkscape --without-gui --file="$pdf" --export-plain-svg="data/svg/${base}.svg"
done

