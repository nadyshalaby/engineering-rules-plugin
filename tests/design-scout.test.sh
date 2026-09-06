#!/bin/bash
# Runs the design scout's shell block straight out of 15.29 against a throwaway git repo with
# one planted instance per mechanical tell, and expects every hit under its own tell id, every
# allowed line and every non-UI file left alone, and a coverage line whose buckets add up.
# Run: bash tests/design-scout.test.sh
# DESIGN_SCOUT_MD points the test at another copy of 15.29, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
DOC="${DESIGN_SCOUT_MD:-$ROOT/skills/engineering-rules/references/15-design/15.29-the-design-scout.md}"

# The HOW block, with its <base>..HEAD placeholder pointed at the fixture's base commit.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$DOC" \
    | sed "s/\"<base>..HEAD\"/\"$1..HEAD\"/"
}

# Bytes the fixtures need, produced with printf so this file stays ASCII.
EMDASH=$(printf '\342\200\224')
MIDDOT=$(printf '\302\267')
DEGREE=$(printf '\302\260')
SPARKLE=$(printf '\342\234\250')

# A hero carrying one instance of most markup-level tells, in a path with a space too.
plant_hero() {
  cat > src/Hero.tsx <<EOF
export function Hero() {
  return (
    <section className="h-screen relative">
      <span className="text-[11px] uppercase tracking-[0.2em]">BETA</span>
      <h1>Built for teams ${EMDASH} not committees<br /><em>years.</em></h1>
      <p>Elevate your workflow with a seamless flow. Lorem ipsum dolor.</p>
      <p>Quietly in use at Acme and Nexus. 99.99% uptime.</p>
      <p>Reading: 14:23 ${MIDDOT} 18${DEGREE}C ${MIDDOT} Lisbon</p>
      <a href="#" className="bg-white text-white px-4">Get in touch</a>
      <a href="/contact" className="italic leading-none">Let's talk</a>
      <p>Scroll to explore ${SPARKLE}</p>
      <p>01 / 4</p>
      <p>Step 1 of 3</p>
      <p>00 orchestration layer</p>
      <p>BRAND. MOTION. SPATIAL.</p>
      <img src="https://images.unsplash.com/photo-1" alt="image" />
      <img src="https://picsum.photos/seed/atelier/800/600" alt="A bench" />
      <span>John Doe</span>
    </section>
  )
}
EOF
  printf '<p>A %s B</p>\n' "$EMDASH" > 'src/my hero.tsx'
  printf '<p>C %s D</p>\n' "$EMDASH" > -dash.tsx
}

# Style and theme files carrying the style-level and file-level tells.
plant_styles() {
  cat > src/theme.css <<'EOF'
:root { --font-sans: Inter; }
body { font-family: Inter, sans-serif; color: #000000; }
h1 { font-family: 'Fraunces', serif; }
h2 { font-family: 'Space Grotesk', sans-serif; }
.cursor { cursor: url(/c.png), auto; }
.modal { z-index: 9999; backdrop-filter: blur(12px); }
.panel { transition: width 0.3s ease-in-out; }
.col { width: calc(33% - 1rem); }
.paper { background: #f5f1ea; color: #b08947; }
.glow { background: #7c3aed; }
@keyframes float { from { transform: none } to { transform: translateY(-4px) } }
.grain { background-image: url(noise.png); }
EOF
  cat > src/scroll.ts <<'EOF'
import { Inter } from 'next/font/google'
import { ArrowRight } from 'lucide-react'
window.addEventListener('scroll', onScroll)
// TODO(owner): wire the rest of the code
EOF
  cat > src/Grid.tsx <<'EOF'
export function Grid({ rows }: GridProps) {
  return (
    <ul className="grid grid-cols-3 gap-4">
      {rows.map((r) => <li key={r.id} className="border-t border-b py-2">{r.name}</li>)}
    </ul>
  )
}
EOF
  cat > src/Logos.tsx <<'EOF'
export function Logos() {
  return (
    <div>
      <Marquee speed={40}>a</Marquee>
      <Marquee speed={40}>b</Marquee>
    </div>
  )
}
EOF
  cat > src/Sections.tsx <<'EOF'
export function Sections() {
  return (
    <>
      <section><p className="uppercase tracking-widest">One</p></section>
      <section><p className="uppercase tracking-widest">Two</p></section>
      <section><p className="uppercase tracking-widest">Three</p></section>
      <section><h2>Four</h2></section>
    </>
  )
}
EOF
  cat > src/Icon.tsx <<'EOF'
export const Icon = () => (
  <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" /></svg>
)
EOF
}

# Lines the law allows, which must stay silent, and files outside this scout's scope.
plant_allowed_and_out_of_scope() {
  cat > src/clean.tsx <<'EOF'
export function Clean() {
  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-6 min-h-[100dvh]">
      <a href="/pricing" className="bg-white/10 text-white">Pricing</a>
      <img src="/hero.jpg" alt="A ceramic pot on a workbench" />
    </section>
  )
}
EOF
  cat > src/allowed.css <<'EOF'
body { font-family: 'Geist', Inter, sans-serif; background: #fff; }
@keyframes rise { from { opacity: 0 } to { opacity: 1 } }
@media (prefers-reduced-motion: reduce) { * { animation: none } }
.noise { position: fixed; inset: 0; pointer-events: none; background-image: url(grain.png); }
EOF
  mkdir -p web
  printf '<h1>Home %s page</h1>\n' "$EMDASH" > web/Home.cshtml
  printf '# Notes %s John Doe wrote these\n' "$EMDASH" > README.md
  printf 'print("Acme")\n' > script.py
}

build_fixture() (
  git init -q "$WORK/repo" && cd "$WORK/repo" || return 1
  git -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
  mkdir src
  plant_hero && plant_styles && plant_allowed_and_out_of_scope || return 1
  git add -- src web README.md script.py -dash.tsx
  git -c user.name=t -c user.email=t@example.com commit -q -m planted
)

run_block() (
  cd "$WORK/repo" || return 1
  extract_block "$(git rev-parse HEAD~1)" > "$WORK/block.sh"
  SCOUT_PATHS="$WORK/paths" bash "$WORK/block.sh" 2>&1
)

test_finds_every_planted_markup_tell() {
  assert_contains "em-dash in the hero" "tell.punct.em-dash src/Hero.tsx:5:" "$out"
  assert_contains "em-dash in a path with a space" "tell.punct.em-dash src/my hero.tsx:1:" "$out"
  assert_contains "em-dash in a path that starts with a dash" "tell.punct.em-dash -dash.tsx:1:" "$out"
  assert_contains "middle-dot chain" "tell.punct.middle-dot-chain src/Hero.tsx:8:" "$out"
  assert_contains "locale strip with a temperature" "tell.label.locale-strip src/Hero.tsx:8:" "$out"
  assert_contains "emoji in copy" "tell.asset.emoji-as-icon src/Hero.tsx:11:" "$out"
  assert_contains "scroll cue" "tell.hero.scroll-cue src/Hero.tsx:11:" "$out"
  assert_contains "version label in the hero" "tell.hero.version-label src/Hero.tsx:4:" "$out"
  assert_contains "section number label" "tell.label.section-number src/Hero.tsx:12:" "$out"
  assert_contains "step numbering" "tell.label.step-numbering src/Hero.tsx:13:" "$out"
  assert_contains "pseudo-system label" "tell.label.pseudo-system src/Hero.tsx:14:" "$out"
  assert_contains "decoration strip" "tell.hero.decoration-strip src/Hero.tsx:15:" "$out"
  assert_contains "lorem ipsum" "tell.copy.lorem src/Hero.tsx:6:" "$out"
  assert_contains "filler verb" "tell.copy.filler-verb src/Hero.tsx:6:" "$out"
  assert_contains "quietly trusted" "tell.copy.quietly-trusted src/Hero.tsx:7:" "$out"
  assert_contains "slop brand" "tell.copy.slop-brand src/Hero.tsx:7:" "$out"
  assert_contains "fake perfect number" "tell.copy.fake-perfect-number src/Hero.tsx:7:" "$out"
  assert_contains "generic name" "tell.copy.generic-name src/Hero.tsx:18:" "$out"
  assert_contains "dead link" "tell.state.dead-link src/Hero.tsx:9:" "$out"
  assert_contains "white text on a white fill" "tell.state.white-on-white-button src/Hero.tsx:9:" "$out"
  assert_contains "italic descender clip" "tell.type.italic-clip src/Hero.tsx:10:" "$out"
  assert_contains "br plus italic headline" "tell.punct.br-italic-headline src/Hero.tsx:5:" "$out"
  assert_contains "h-screen" "tell.layout.h-screen src/Hero.tsx:3:" "$out"
  assert_contains "generic alt text" "tell.chrome.missing-alt src/Hero.tsx:16:" "$out"
  assert_contains "unsplash url" "tell.asset.broken-unsplash src/Hero.tsx:16:" "$out"
  assert_contains "placeholder image service" "tell.asset.placeholder-shipped src/Hero.tsx:17:" "$out"
  assert_contains "two labels for one intent" "tell.copy.duplicate-cta-intent scope: contact intent carries 2 labels" "$out"
  assert_contains "eyebrow budget exceeded" "tell.label.eyebrow-everywhere scope: 4 eyebrow candidates against 6 sections, budget 2" "$out"
  assert_contains "two marquees" "tell.motion.two-marquees scope: 2 marquee elements" "$out"
  assert_contains "hand-rolled icon path" "tell.asset.hand-rolled-icon src/Icon.tsx:2:" "$out"
  assert_contains "divider on every row" "tell.layout.divider-every-row src/Grid.tsx:4:" "$out"
  assert_contains "multi-column grid with no narrower variant" "tell.layout.mobile-implicit src/Grid.tsx:1:" "$out"
}

test_finds_every_planted_style_and_theme_tell() {
  assert_contains "inter as the first family" "tell.type.inter-default src/theme.css:2:" "$out"
  assert_contains "inter as a custom property" "tell.type.inter-default src/theme.css:1:" "$out"
  assert_contains "inter via a framework font import" "tell.type.inter-default src/scroll.ts:1:" "$out"
  assert_contains "pure black" "tell.visual.pure-black src/theme.css:2:" "$out"
  assert_contains "serif reflex" "tell.type.serif-reflex src/theme.css:3:" "$out"
  assert_contains "space grotesk" "tell.type.space-grotesk src/theme.css:4:" "$out"
  assert_contains "custom cursor" "tell.visual.custom-cursor src/theme.css:5:" "$out"
  assert_contains "z-index spam" "tell.chrome.z-index-spam src/theme.css:6:" "$out"
  assert_contains "backdrop blur" "tell.visual.default-backdrop-blur src/theme.css:6:" "$out"
  assert_contains "transition on a layout property" "tell.motion.layout-property src/theme.css:7:" "$out"
  assert_contains "ease-in-out easing" "tell.motion.linear-easing src/theme.css:7:" "$out"
  assert_contains "flex percentage math" "tell.layout.flex-math src/theme.css:8:" "$out"
  assert_contains "beige and brass palette" "tell.visual.premium-beige-brass src/theme.css:9:" "$out"
  assert_contains "ai purple" "tell.visual.ai-purple src/theme.css:10:" "$out"
  assert_contains "animation with no reduced-motion path" "tell.motion.no-reduced-motion src/theme.css:1:" "$out"
  assert_contains "grain with no fixed layer" "tell.asset.grain-on-scroller src/theme.css:1:" "$out"
  assert_contains "window scroll listener" "tell.motion.scroll-listener src/scroll.ts:3:" "$out"
  assert_contains "lucide import" "tell.asset.lucide-reflex src/scroll.ts:2:" "$out"
  assert_contains "placeholder comment" "tell.chrome.placeholder-comment src/scroll.ts:4:" "$out"
}

test_leaves_the_allowed_alone_and_stays_in_scope() {
  assert_missing "the clean component stays silent" "src/clean.tsx" "$out"
  assert_missing "a fallback Inter is not the first family" "src/allowed.css:1:" "$out"
  assert_missing "an animation with a reduced-motion path" "tell.motion.no-reduced-motion src/allowed.css" "$out"
  assert_missing "grain on a fixed layer" "tell.asset.grain-on-scroller src/allowed.css" "$out"
  assert_missing "prose is out of scope" "README.md" "$out"
  assert_missing "python is out of scope" "script.py" "$out"
  assert_missing "a cshtml view is not scanned" "tell.punct.em-dash web/Home.cshtml" "$out"
  assert_missing "no path text ever runs as code" "INJECTED" "$out"
  untagged=$(printf '%s\n' "$out" | grep -vE '^tell\.[a-z]+\.[a-z-]+ ' | grep -vE '^[[:space:]]*[0-9]+$' | grep -vE '^scope [0-9]+ \|')
  assert_contains "every printed line carries its tell id, a count, or the coverage line" "<none>" "${untagged:-<none>}"
}

test_coverage_buckets_add_up() {
  pair=$(printf '%s\n' "$out" | grep -E '^[[:space:]]*[0-9]+$' | tr -d ' ' | tr '\n' '/')
  assert_contains "handed in equals readable" "$PLANTED/$PLANTED/" "$pair"
  cov=$(printf '%s\n' "$out" | grep -E '^scope [0-9]+ \|')
  assert_contains "the razor-style view is named as missing coverage" "no table: web/Home.cshtml" "$cov"
  assert_contains "prose and python are out of scope, not gaps" "out of this scout's scope 2" "$cov"
  assert_contains "the scope count is the planted count" "scope $PLANTED |" "$cov"
}

test_refuses_a_list_without_nul() {
  printf 'src/clean.tsx\nsrc/Hero.tsx\n' > "$WORK/newline-paths"
  guard=$(grep -F 'not NUL-separated' "$WORK/block.sh")
  out=$(SCOUT_PATHS="$WORK/newline-paths" bash -c "$guard" 2>&1; echo "exit=$?")
  assert_contains "a list built without -z is refused" "SCOUT_PATHS is not NUL-separated" "$out"
  assert_contains "and the block stops" "exit=1" "$out"
}

test_runs_under_set_u() {
  out=$(cd "$WORK/repo" && SCOUT_PATHS="$WORK/paths" bash -u "$WORK/block.sh" 2>&1)
  assert_missing "no unbound variable under set -u" "unbound variable" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
PLANTED=$(git -C "$WORK/repo" ls-files | wc -l | tr -d ' ')
printf 'const quiet = 1\n' > "$WORK/repo/src/a\";echo INJECTED;\".tsx"
out=$(run_block)
test_finds_every_planted_markup_tell
test_finds_every_planted_style_and_theme_tell
test_leaves_the_allowed_alone_and_stays_in_scope
test_coverage_buckets_add_up
test_refuses_a_list_without_nul
test_runs_under_set_u
report
