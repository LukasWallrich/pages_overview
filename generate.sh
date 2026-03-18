#!/usr/bin/env bash
set -euo pipefail

OWNER="LukasWallrich"
OUTFILE="index.html"

# Fetch all repos with pages enabled
repos_json=$(gh api "/users/${OWNER}/repos?per_page=100&type=owner" \
  --jq '[.[] | select(.has_pages == true) | {name: .name, description: (.description // ""), url: .html_url}] | sort_by(.name | ascii_downcase)')

count=$(echo "$repos_json" | jq 'length')
updated=$(date -u +"%Y-%m-%d")

# Build cards HTML into a temp file
cards_file=$(mktemp)
echo "$repos_json" | jq -c '.[]' | while IFS= read -r repo; do
  name=$(echo "$repo" | jq -r '.name')
  description=$(echo "$repo" | jq -r '.description')

  pages_url=$(gh api "/repos/${OWNER}/${name}/pages" --jq '.html_url' 2>/dev/null || echo "")
  [ -z "$pages_url" ] && continue

  # Escape HTML entities
  desc_escaped=$(echo "$description" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  name_escaped=$(echo "$name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

  echo "        <a href=\"${pages_url}\" class=\"card\" target=\"_blank\" rel=\"noopener\">" >> "$cards_file"
  echo "          <h2>${name_escaped}</h2>" >> "$cards_file"
  if [ -n "$description" ]; then
    echo "          <p>${desc_escaped}</p>" >> "$cards_file"
  fi
  echo "          <span class=\"link\">Visit page &rarr;</span>" >> "$cards_file"
  echo "        </a>" >> "$cards_file"
done

# Assemble final HTML: template head, cards, template tail
head -n 109 template.html | sed "s/{{COUNT}}/${count}/; s/{{UPDATED}}/${updated}/" > "$OUTFILE"
cat "$cards_file" >> "$OUTFILE"
tail -n +111 template.html >> "$OUTFILE"

rm -f "$cards_file"
echo "Generated ${OUTFILE} with ${count} pages (${updated})"
