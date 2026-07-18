#!/opt/homebrew/bin/bash
# eval-slug.sh — measure how well a local `slm` model turns GitHub issues into
# branch slugs (the job `bin/i` does). NOT a pass/fail gate: slm output is
# non-deterministic and model-dependent, so this prints scores you read, and
# always exits 0 (SKIP when LM Studio is unreachable).
#
#   scripts/eval-slug.sh              # 30-case curated quick set, current model
#   scripts/eval-slug.sh --full       # all 188 cases
#   scripts/eval-slug.sh -n 10        # first 10 of the selected set
#   SLM_MODEL=Qwen2.5-3B-… scripts/eval-slug.sh   # rank a candidate model
#   scripts/eval-slug.sh -m <model>   # same, via flag
#
# Ground truth: `scripts/eval-slug-fixtures.jsonl` — real merged ccpulse +
# dotfiles PRs from BEFORE slm existed, so each `<issue>-<slug>` branch is a
# human-authored gold slug paired with its issue's title+body. The runner
# routes title+description through the SAME pipeline `bin/i` uses (the shared
# `bin/_slug-from-issue` helper) and scores the result three ways:
#   • keyword overlap  — token Jaccard vs gold (robust to word order and to
#     gold-label typos like `uniqe-constraint`); the headline metric.
#   • exact match      — strict, secondary (an LLM rarely nails it verbatim).
#   • ≤3-word sanity   — did the model obey "2-3 keywords"? (instruction follow)
#
# Quick set runtime ≈ 1 fish+slm call per case; budget a few seconds per case.
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$DOTFILES/scripts/eval-slug-fixtures.jsonl"
HELPER="$DOTFILES/bin/_slug-from-issue"

FULL=false
LIMIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    --full)  FULL=true; shift ;;
    -n)      LIMIT="${2:?-n needs a number}"; shift 2 ;;
    -m)      export SLM_MODEL="${2:?-m needs a model}"; shift 2 ;;
    *) echo "eval-slug: unknown arg '$1' (try -h)" >&2; exit 2 ;;
  esac
done

for tool in fish jq curl awk; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "⏭️  $tool not installed — skipping slug eval"; exit 0
  fi
done
[ -f "$FIXTURE" ] || { echo "❌ fixture missing: $FIXTURE" >&2; exit 1; }
[ -f "$HELPER" ]  || { echo "❌ helper missing: $HELPER"  >&2; exit 1; }

# LM Studio gate — same probe as test-slm.sh. No server → SKIP (CI-friendly).
SLM_URL_DEFAULT="${SLM_URL:-http://localhost:1234/v1}"
if ! curl -sf -o /dev/null --max-time 2 "$SLM_URL_DEFAULT/models" 2>/dev/null; then
  echo "⏭️  LM Studio not reachable at $SLM_URL_DEFAULT — skipping slug eval"
  echo "    start the LM Studio app (or:  lms server start)"
  exit 0
fi

# The real pipeline: defines SLUG_SYS + slug_from_issue (shared with bin/i).
# shellcheck source=../bin/_slug-from-issue
source "$HELPER"

# overlap GOLD GOT -> "inter union pct" (token Jaccard on '-' separators).
overlap() {
  awk -v a="$1" -v b="$2" 'BEGIN{
    na=(length(a)? split(a,A,"-"):0);
    nb=(length(b)? split(b,B,"-"):0);
    for(i=1;i<=na;i++) sa[A[i]]=1;
    for(i=1;i<=nb;i++) sb[B[i]]=1;
    inter=0; for(k in sa) if(k in sb) inter++;
    for(k in sa) u[k]=1; for(k in sb) u[k]=1; nu=0; for(k in u) nu++;
    printf "%d %d %d", inter, nu, (nu? int(100*inter/nu+0.5):0);
  }'
}

MODEL_LABEL="${SLM_MODEL:-(slm.fish default)}"
SET_LABEL=$([ "$FULL" = true ] && echo "full" || echo "quick")
echo
echo "slug eval · model: $MODEL_LABEL · set: $SET_LABEL"
printf '%s\n' "──────────────────────────────────────────────────────────────"

n=0; exact=0; sane=0; ovsum=0; emptied=0
while IFS= read -r row; do
  [ "$LIMIT" -gt 0 ] && [ "$n" -ge "$LIMIT" ] && break
  repo=$(jq -r '.repo'        <<<"$row")
  issue=$(jq -r '.issue'      <<<"$row")
  gold=$(jq -r '.gold'        <<<"$row")
  title=$(jq -r '.title'      <<<"$row")
  desc=$(jq -r '.description' <<<"$row")

  got=$(slug_from_issue "$title" "$desc")
  n=$((n+1))

  read -r inter union pct < <(overlap "$gold" "$got")
  ovsum=$((ovsum+pct))

  if [ -z "$got" ]; then
    glyph="·"; emptied=$((emptied+1)); words=0
  else
    words=$(awk -F- '{print NF}' <<<"$got")
    if [ "$got" = "$gold" ]; then glyph="✓"; exact=$((exact+1))
    elif [ "$inter" -gt 0 ];   then glyph="◐"
    else                            glyph="✗"; fi
  fi

  flag=""
  [ "$got" = "$gold" ] && flag="exact"
  if [ -n "$got" ] && [ "$words" -ge 1 ] && [ "$words" -le 3 ]; then
    sane=$((sane+1))
  elif [ -n "$got" ]; then
    flag="${flag:+$flag }${words}w!"
  fi

  printf '  %s  %-12s #%-4s kw=%3d%%  gold=%-22s got=%-22s %s\n' \
    "$glyph" "$repo" "$issue" "$pct" "$gold" "${got:-—}" "$flag"
done < <(jq -c --argjson full "$FULL" 'select($full or .quick)' "$FIXTURE")

mean=$(( n>0 ? ovsum/n : 0 ))
echo "──────────────────────────────────────────────────────────────"
printf '  cases: %d   mean keyword overlap: %d%%\n' "$n" "$mean"
printf '  exact: %d/%d   ≤3-word sanity: %d/%d   empty: %d\n' \
  "$exact" "$n" "$sane" "$n" "$emptied"
echo
echo "legend: ✓ exact · ◐ shares keywords · ✗ no overlap · · empty output"
exit 0
