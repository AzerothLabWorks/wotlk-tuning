#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-}"
COMMAND=""
DRY_RUN=0
YES=0
RESTART=0
SKIP_COMPOSE=0
XP_RATE=""
KILL_XP_RATE=""
QUEST_XP_RATE=""
EXPLORE_XP_RATE=""
PET_XP_RATE=""
REP_RATE=""
DROP_RATE=""
MONEY_RATE=""
SKILL_RATE=""
START_LEVEL=""
START_MONEY=""
DUAL_SPEC_LEVEL=""
PERFORMANCE=""

BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKED_UP_FILES=""
DRY_RUN_COMPOSE_OVERRIDE_ANNOUNCED=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/wotlk-tuner.sh [options] COMMAND [args]

Options:
  --server-dir PATH       AzerothCore WotLK server source or install directory.
  --dry-run               Show intended changes without writing files or running Docker.
  --yes                   Do not prompt before restart or restore.
  --restart               Restart ac-worldserver after config changes.
  --skip-compose          Do not update docker-compose.override.yml environment values.
  --xp N                  Override all player XP rates.
  --kill-xp N             Override kill XP rate.
  --quest-xp N            Override quest XP rate.
  --explore-xp N          Override exploration XP rate.
  --pet-xp N              Override pet XP rate.
  --rep N                 Override reputation gain rate.
  --drop N                Override common item drop rates.
  --money N               Override money drop rate.
  --skill N               Override profession and weapon skill gain rates.
  --start-level N         Override new character starting level.
  --start-money COPPER    Override new character starting money in copper.
  --dual-spec-level N     Override dual talent specialization level.
  --performance NAME      Apply a performance profile: low, medium, high.
  -h, --help              Show this help.

Commands:
  list-presets            Show available gameplay presets.
  list-performance        Show performance profiles.
  doctor                  Check install layout and important settings.
  apply-preset NAME       Apply a config preset.
  restore-latest          Restore latest tuner backups for config/compose files.
  restart                 Restart ac-worldserver with Docker Compose.

Presets:
  blizzlike               Conservative AzerothCore defaults for common tuning keys.
  solo-friendly           Lower-friction leveling for one or a few players.
  fast-leveling           Faster leveling without extreme loot inflation.
  alt-friendly            Easier alts, professions, starting money, and dual spec.
  loot-rich               More loot and money for casual private servers.
  reputation-friendly     Faster faction progress with modest XP support.

Examples:
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 5 --restart
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset alt-friendly --performance low
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest --restart
USAGE
}

log() { printf '\033[0;36m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

confirm_or_die() {
  local prompt="$1"
  [[ "$YES" == "1" ]] && return 0
  printf '%s [y/N] ' "$prompt"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Cancelled."
}

parse_args() {
  COMMAND_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --server-dir) SERVER_DIR="${2:-}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes) YES=1; shift ;;
      --restart) RESTART=1; shift ;;
      --skip-compose) SKIP_COMPOSE=1; shift ;;
      --xp) XP_RATE="${2:-}"; shift 2 ;;
      --kill-xp) KILL_XP_RATE="${2:-}"; shift 2 ;;
      --quest-xp) QUEST_XP_RATE="${2:-}"; shift 2 ;;
      --explore-xp) EXPLORE_XP_RATE="${2:-}"; shift 2 ;;
      --pet-xp) PET_XP_RATE="${2:-}"; shift 2 ;;
      --rep) REP_RATE="${2:-}"; shift 2 ;;
      --drop) DROP_RATE="${2:-}"; shift 2 ;;
      --money) MONEY_RATE="${2:-}"; shift 2 ;;
      --skill) SKILL_RATE="${2:-}"; shift 2 ;;
      --start-level) START_LEVEL="${2:-}"; shift 2 ;;
      --start-money) START_MONEY="${2:-}"; shift 2 ;;
      --dual-spec-level) DUAL_SPEC_LEVEL="${2:-}"; shift 2 ;;
      --performance) PERFORMANCE="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      list-presets|list-performance|doctor|apply-preset|restore-latest|restart)
        [[ -z "$COMMAND" ]] || die "Only one command can be used at a time."
        COMMAND="$1"
        shift
        ;;
      *)
        if [[ -n "$COMMAND" ]]; then
          COMMAND_ARGS+=("$1")
          shift
        else
          die "Unknown option or command: $1"
        fi
        ;;
    esac
  done
}

require_server_dir() {
  [[ -n "$SERVER_DIR" ]] || die "SERVER_DIR is not set. Use --server-dir PATH."
  [[ -d "$SERVER_DIR" ]] || die "Server directory does not exist: $SERVER_DIR"
}

require_docker_compose_file() {
  require_server_dir
  [[ -f "$SERVER_DIR/docker-compose.yml" || -f "$SERVER_DIR/compose.yml" ]] || die "No docker-compose.yml or compose.yml found in: $SERVER_DIR"
}

find_worldserver_dist_config() {
  local candidates=(
    "$SERVER_DIR/env/dist/etc/worldserver.conf.dist"
    "$SERVER_DIR/env/dist/configs/worldserver.conf.dist"
    "$SERVER_DIR/etc/worldserver.conf.dist"
    "$SERVER_DIR/configs/worldserver.conf.dist"
    "$SERVER_DIR/src/server/apps/worldserver/worldserver.conf.dist"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  find "$SERVER_DIR" -name 'worldserver.conf.dist' -type f 2>/dev/null | head -1
}

find_worldserver_config() {
  local candidates=(
    "$SERVER_DIR/env/dist/etc/worldserver.conf"
    "$SERVER_DIR/env/dist/configs/worldserver.conf"
    "$SERVER_DIR/etc/worldserver.conf"
    "$SERVER_DIR/configs/worldserver.conf"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  find "$SERVER_DIR" -name 'worldserver.conf' -type f 2>/dev/null | head -1
}

target_config_for_dist() {
  local dist_file="$1"
  case "$dist_file" in
    *.dist) printf '%s\n' "${dist_file%.dist}" ;;
    *) printf '%s/env/dist/etc/worldserver.conf\n' "$SERVER_DIR" ;;
  esac
}

ensure_worldserver_config() {
  require_server_dir

  local config_file
  config_file="$(find_worldserver_config || true)"
  if [[ -n "$config_file" ]]; then
    printf '%s\n' "$config_file"
    return 0
  fi

  local dist_file
  dist_file="$(find_worldserver_dist_config || true)"
  [[ -n "$dist_file" ]] || die "Could not find worldserver.conf or worldserver.conf.dist. Is this an AzerothCore WotLK server folder?"

  local target_file
  target_file="$(target_config_for_dist "$dist_file")"
  local target_dir
  target_dir="$(dirname "$target_file")"

  log "Creating runtime worldserver config from: $dist_file"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] mkdir -p %q\n' "$target_dir" >&2
    printf '[dry-run] cp %q %q\n' "$dist_file" "$target_file" >&2
  else
    mkdir -p "$target_dir"
    cp "$dist_file" "$target_file"
  fi

  printf '%s\n' "$target_file"
}

compose_override_file() {
  printf '%s\n' "$SERVER_DIR/docker-compose.override.yml"
}

backup_file_once() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  [[ " $BACKED_UP_FILES " == *" $file "* ]] && return 0

  local backup="${file}.bak.${BACKUP_STAMP}"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cp %q %q\n' "$file" "$backup"
  else
    cp "$file" "$backup"
  fi
  BACKED_UP_FILES="$BACKED_UP_FILES $file"
}

latest_backup_for() {
  local file="$1"
  local latest=""

  shopt -s nullglob
  local backups=("${file}".bak.*)
  shopt -u nullglob

  [[ ${#backups[@]} -gt 0 ]] || return 1
  latest="$(ls -t "${backups[@]}" 2>/dev/null | head -1 || true)"
  [[ -n "$latest" ]] || return 1
  printf '%s\n' "$latest"
}

find_latest_config_backup() {
  local config
  config="$(find_worldserver_config || true)"
  if [[ -n "$config" ]] && latest_backup_for "$config" >/dev/null 2>&1; then
    latest_backup_for "$config"
    return 0
  fi

  shopt -s nullglob
  local backups=(
    "$SERVER_DIR"/env/dist/etc/worldserver.conf.bak.*
    "$SERVER_DIR"/env/dist/configs/worldserver.conf.bak.*
    "$SERVER_DIR"/etc/worldserver.conf.bak.*
    "$SERVER_DIR"/configs/worldserver.conf.bak.*
  )
  shopt -u nullglob

  [[ ${#backups[@]} -gt 0 ]] || return 1
  ls -t "${backups[@]}" 2>/dev/null | head -1
}

restore_backup_file() {
  local backup="$1"
  local target="${backup%.bak.*}"

  [[ -f "$backup" ]] || die "Backup file does not exist: $backup"
  confirm_or_die "Restore $backup to $target?"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cp %q %q\n' "$backup" "$target"
    log "Would restore $target from $(basename "$backup")."
  else
    cp "$backup" "$target"
    log "Restored $target from $(basename "$backup")."
  fi
}

require_number() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "$label must be a non-negative number using a period for decimals: $value"
}

require_integer() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$label must be a non-negative integer: $value"
}

conf_key_regex() {
  local key="$1"
  printf '%s\n' "$key" | sed 's/[.[\*^$()+?{}|\\]/\\&/g'
}

set_conf_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local key_regex
  key_regex="$(conf_key_regex "$key")"

  backup_file_once "$file"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] set %s = %s in %s\n' "$key" "$value" "$file"
    return 0
  fi

  if grep -qE "^[[:space:]]*#?[[:space:]]*${key_regex}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key_regex}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    printf '\n%s = %s\n' "$key" "$value" >> "$file"
  fi
}

ensure_compose_override() {
  local file
  file="$(compose_override_file)"

  if [[ -f "$file" ]]; then
    printf '%s\n' "$file"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$DRY_RUN_COMPOSE_OVERRIDE_ANNOUNCED" == "0" ]]; then
      printf '[dry-run] create %s with ac-worldserver environment block\n' "$file" >&2
      DRY_RUN_COMPOSE_OVERRIDE_ANNOUNCED=1
    fi
  else
    printf 'services:\n  ac-worldserver:\n    environment: {}\n' > "$file"
  fi
  printf '%s\n' "$file"
}

set_compose_environment_value() {
  [[ "$SKIP_COMPOSE" == "1" ]] && return 0

  local key="$1"
  local value="$2"
  local file
  file="$(ensure_compose_override)"
  backup_file_once "$file"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] set %s: "%s" in %s\n' "$key" "$value" "$file"
    return 0
  fi

  if grep -qE "^[[:space:]]+${key}:" "$file"; then
    sed -i -E "s|^([[:space:]]+${key}:).*|\\1 \"${value}\"|" "$file"
    return 0
  fi

  local temp_file
  temp_file="$(mktemp)"
  if awk -v key="$key" -v value="$value" '
    {
      if (!inserted && $0 ~ /^[[:space:]]+environment:[[:space:]]*(\{\})?[[:space:]]*$/) {
        match($0, /^[[:space:]]+/)
        indent = substr($0, RSTART, RLENGTH)
        if ($0 ~ /\{\}/) {
          print indent "environment:"
          print indent "  " key ": \"" value "\""
        } else {
          print
          print indent "  " key ": \"" value "\""
        }
        inserted = 1
      } else {
        print
      }
    }
    END { exit inserted ? 0 : 1 }
  ' "$file" > "$temp_file"; then
    mv "$temp_file" "$file"
  else
    rm -f "$temp_file"
    warn "Could not find environment block in $file. Leaving $key unchanged."
  fi
}

config_key_to_env() {
  local key="$1"
  printf 'AC_%s\n' "$key" \
    | sed -E 's/[.]/_/g; s/([A-Z]+)([A-Z][a-z])/\1_\2/g; s/([a-z0-9])([A-Z])/\1_\2/g; s/([A-Za-z])([0-9])/\1_\2/g; s/([0-9])([A-Za-z])/\1_\2/g' \
    | tr '[:lower:]' '[:upper:]'
}

set_world_value() {
  local config="$1"
  local key="$2"
  local value="$3"
  local env_key
  set_conf_value "$config" "$key" "$value"
  env_key="$(config_key_to_env "$key")"
  set_compose_environment_value "$env_key" "$value"
}

set_xp_rates() {
  local config="$1"
  local rate="$2"
  require_number "XP rate" "$rate"
  set_world_value "$config" "Rate.XP.Kill" "$rate"
  set_world_value "$config" "Rate.XP.Quest" "$rate"
  set_world_value "$config" "Rate.XP.Quest.DF" "$rate"
  set_world_value "$config" "Rate.XP.Explore" "$rate"
  set_world_value "$config" "Rate.XP.Pet" "$rate"
}

set_reputation_rates() {
  local config="$1"
  local rate="$2"
  require_number "Reputation rate" "$rate"
  set_world_value "$config" "Rate.Reputation.Gain" "$rate"
  set_world_value "$config" "Rate.Reputation.LowLevel.Kill" "$rate"
  set_world_value "$config" "Rate.Reputation.LowLevel.Quest" "$rate"
  set_world_value "$config" "Rate.Reputation.RecruitAFriendBonus" "$rate"
}

set_drop_rates() {
  local config="$1"
  local rate="$2"
  require_number "Drop rate" "$rate"
  set_world_value "$config" "Rate.Drop.Item.Poor" "$rate"
  set_world_value "$config" "Rate.Drop.Item.Normal" "$rate"
  set_world_value "$config" "Rate.Drop.Item.Uncommon" "$rate"
  set_world_value "$config" "Rate.Drop.Item.Rare" "$rate"
  set_world_value "$config" "Rate.Drop.Item.Epic" "$rate"
}

set_money_rate() {
  local config="$1"
  local rate="$2"
  require_number "Money rate" "$rate"
  set_world_value "$config" "Rate.Drop.Money" "$rate"
}

set_skill_rates() {
  local config="$1"
  local rate="$2"
  require_number "Skill rate" "$rate"
  set_world_value "$config" "SkillGain.Crafting" "$rate"
  set_world_value "$config" "SkillGain.Defense" "$rate"
  set_world_value "$config" "SkillGain.Gathering" "$rate"
  set_world_value "$config" "SkillGain.Weapon" "$rate"
}

apply_performance_profile() {
  local config="$1"
  local profile="$2"
  [[ -n "$profile" ]] || return 0

  case "$profile" in
    low)
      set_world_value "$config" "GridUnload" "1"
      set_world_value "$config" "MapUpdate.Threads" "1"
      set_world_value "$config" "Network.Threads" "1"
      set_world_value "$config" "ThreadPool" "2"
      set_world_value "$config" "Visibility.Distance.Continents" "70"
      set_world_value "$config" "Visibility.Distance.Instances" "80"
      ;;
    medium)
      set_world_value "$config" "GridUnload" "1"
      set_world_value "$config" "MapUpdate.Threads" "2"
      set_world_value "$config" "Network.Threads" "1"
      set_world_value "$config" "ThreadPool" "4"
      set_world_value "$config" "Visibility.Distance.Continents" "90"
      set_world_value "$config" "Visibility.Distance.Instances" "100"
      ;;
    high)
      set_world_value "$config" "GridUnload" "1"
      set_world_value "$config" "MapUpdate.Threads" "4"
      set_world_value "$config" "Network.Threads" "2"
      set_world_value "$config" "ThreadPool" "8"
      set_world_value "$config" "Visibility.Distance.Continents" "100"
      set_world_value "$config" "Visibility.Distance.Instances" "120"
      ;;
    *) die "Unknown performance profile: $profile. Use low, medium, or high." ;;
  esac
}

apply_blizzlike() {
  local config="$1"
  set_xp_rates "$config" "1"
  set_reputation_rates "$config" "1"
  set_drop_rates "$config" "1"
  set_money_rate "$config" "1"
  set_skill_rates "$config" "1"
  set_world_value "$config" "Rate.Talent" "1"
  set_world_value "$config" "Rate.Talent.Pet" "1"
  set_world_value "$config" "Rate.Honor" "1"
  set_world_value "$config" "Rate.ArenaPoints" "1"
  set_world_value "$config" "Rate.RepairCost" "1"
  set_world_value "$config" "StartPlayerLevel" "1"
  set_world_value "$config" "StartHeroicPlayerLevel" "55"
  set_world_value "$config" "StartPlayerMoney" "0"
  set_world_value "$config" "MinDualSpecLevel" "40"
  set_world_value "$config" "SkipCinematics" "0"
}

apply_solo_friendly() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "1.5"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "1.5"
  set_world_value "$config" "Rate.RepairCost" "0.5"
  set_world_value "$config" "MinDualSpecLevel" "30"
  set_world_value "$config" "SkipCinematics" "1"
}

apply_fast_leveling() {
  local config="$1"
  set_xp_rates "$config" "5"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "1"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "2"
  set_world_value "$config" "Rate.RepairCost" "0.5"
  set_world_value "$config" "MinDualSpecLevel" "20"
  set_world_value "$config" "SkipCinematics" "1"
}

apply_alt_friendly() {
  local config="$1"
  set_xp_rates "$config" "3"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "1.5"
  set_money_rate "$config" "3"
  set_skill_rates "$config" "3"
  set_world_value "$config" "StartPlayerMoney" "100000"
  set_world_value "$config" "StartHeroicPlayerMoney" "100000"
  set_world_value "$config" "MinDualSpecLevel" "20"
  set_world_value "$config" "SkipCinematics" "2"
}

apply_loot_rich() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "3"
  set_money_rate "$config" "4"
  set_skill_rates "$config" "2"
  set_world_value "$config" "Rate.Drop.Item.ReferencedAmount" "1.5"
  set_world_value "$config" "Rate.Drop.Item.GroupAmount" "1.5"
  set_world_value "$config" "Rate.RepairCost" "0.5"
}

apply_reputation_friendly() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "4"
  set_drop_rates "$config" "1"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "1.5"
  set_world_value "$config" "Rate.Reputation.WSG" "4"
  set_world_value "$config" "Rate.Reputation.AB" "4"
  set_world_value "$config" "Rate.Reputation.AV" "4"
}

apply_overrides() {
  local config="$1"

  if [[ -n "$XP_RATE" ]]; then set_xp_rates "$config" "$XP_RATE"; fi
  if [[ -n "$KILL_XP_RATE" ]]; then require_number "--kill-xp" "$KILL_XP_RATE"; set_world_value "$config" "Rate.XP.Kill" "$KILL_XP_RATE"; fi
  if [[ -n "$QUEST_XP_RATE" ]]; then require_number "--quest-xp" "$QUEST_XP_RATE"; set_world_value "$config" "Rate.XP.Quest" "$QUEST_XP_RATE"; set_world_value "$config" "Rate.XP.Quest.DF" "$QUEST_XP_RATE"; fi
  if [[ -n "$EXPLORE_XP_RATE" ]]; then require_number "--explore-xp" "$EXPLORE_XP_RATE"; set_world_value "$config" "Rate.XP.Explore" "$EXPLORE_XP_RATE"; fi
  if [[ -n "$PET_XP_RATE" ]]; then require_number "--pet-xp" "$PET_XP_RATE"; set_world_value "$config" "Rate.XP.Pet" "$PET_XP_RATE"; fi
  if [[ -n "$REP_RATE" ]]; then set_reputation_rates "$config" "$REP_RATE"; fi
  if [[ -n "$DROP_RATE" ]]; then set_drop_rates "$config" "$DROP_RATE"; fi
  if [[ -n "$MONEY_RATE" ]]; then set_money_rate "$config" "$MONEY_RATE"; fi
  if [[ -n "$SKILL_RATE" ]]; then set_skill_rates "$config" "$SKILL_RATE"; fi
  if [[ -n "$START_LEVEL" ]]; then require_integer "--start-level" "$START_LEVEL"; set_world_value "$config" "StartPlayerLevel" "$START_LEVEL"; fi
  if [[ -n "$START_MONEY" ]]; then require_integer "--start-money" "$START_MONEY"; set_world_value "$config" "StartPlayerMoney" "$START_MONEY"; fi
  if [[ -n "$DUAL_SPEC_LEVEL" ]]; then require_integer "--dual-spec-level" "$DUAL_SPEC_LEVEL"; set_world_value "$config" "MinDualSpecLevel" "$DUAL_SPEC_LEVEL"; fi
  apply_performance_profile "$config" "$PERFORMANCE"
}

list_presets() {
  cat <<'PRESETS'
blizzlike             Conservative AzerothCore defaults for common tuning keys.
solo-friendly         2x XP/rep, modest drops, cheaper repairs, easier dual spec.
fast-leveling         5x XP with modest rep/money support for quick progression.
alt-friendly          3x XP, faster skills, starter money, and alt conveniences.
loot-rich             Higher item and money drops for casual private servers.
reputation-friendly   Faster faction gains with modest leveling support.
PRESETS
}

list_performance() {
  cat <<'PERFORMANCE'
low      Steam Deck, older laptops, small VPS hosts, or WSL on modest hardware.
medium   General desktop/server use. This is the safest default profile.
high     Strong hosts with spare CPU and memory for larger groups or heavier modules.
PERFORMANCE
}

apply_preset() {
  local preset="${1:-}"
  [[ -n "$preset" ]] || die "Missing preset name. Run list-presets."

  local config
  config="$(ensure_worldserver_config)"
  log "Applying preset '$preset' to: $config"

  case "$preset" in
    blizzlike) apply_blizzlike "$config" ;;
    solo-friendly) apply_solo_friendly "$config" ;;
    fast-leveling) apply_fast_leveling "$config" ;;
    alt-friendly) apply_alt_friendly "$config" ;;
    loot-rich) apply_loot_rich "$config" ;;
    reputation-friendly) apply_reputation_friendly "$config" ;;
    *) die "Unknown preset: $preset" ;;
  esac

  apply_overrides "$config"

  log "Preset '$preset' complete."
  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for config changes to take effect."
  fi
}

docker_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    return 127
  fi
}

restart_worldserver() {
  require_docker_compose_file
  confirm_or_die "Restart ac-worldserver in $SERVER_DIR?"
  log "Restarting ac-worldserver..."
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cd %q && docker compose restart ac-worldserver\n' "$SERVER_DIR"
  else
    (cd "$SERVER_DIR" && docker_compose restart ac-worldserver)
  fi
}

grep_config() {
  local config="$1"
  local pattern="$2"
  if [[ -f "$config" ]]; then
    grep -E "$pattern" "$config" || true
  else
    warn "Config file not found: $config"
  fi
}

doctor() {
  require_server_dir
  log "Server directory: $SERVER_DIR"

  local config
  config="$(find_worldserver_config || true)"
  if [[ -n "$config" ]]; then
    log "Found worldserver config: $config"
  else
    warn "No worldserver.conf found. apply-preset can create one from worldserver.conf.dist."
    local dist
    dist="$(find_worldserver_dist_config || true)"
    if [[ -n "$dist" ]]; then
      log "Found worldserver dist config: $dist"
    else
      warn "No worldserver.conf.dist found."
    fi
  fi

  if [[ -n "${config:-}" ]]; then
    log "Current common tuning values"
    grep_config "$config" '^[[:space:]]*(Rate\.XP\.(Kill|Quest|Quest\.DF|Explore|Pet)|Rate\.Reputation\.(Gain|LowLevel\.Kill|LowLevel\.Quest|WSG|AB|AV)|Rate\.Drop\.(Money|Item\.(Poor|Normal|Uncommon|Rare|Epic|ReferencedAmount|GroupAmount))|SkillGain\.(Crafting|Defense|Gathering|Weapon)|Start(Player|HeroicPlayer)(Level|Money)|MinDualSpecLevel|SkipCinematics|GridUnload|MapUpdate\.Threads|Network\.Threads|ThreadPool|Visibility\.Distance\.(Continents|Instances))[[:space:]]*='
  fi

  local override
  override="$(compose_override_file)"
  if [[ -f "$override" ]]; then
    log "Found Docker compose override: $override"
    grep -E 'AC_RATE_|AC_SKILLGAIN_|AC_START|AC_MINDUALSPECLEVEL|AC_SKIPCINEMATICS|AC_GRIDUNLOAD|AC_MAPUPDATE_|AC_NETWORK_|AC_THREADPOOL|AC_VISIBILITY_' "$override" || true
  else
    warn "No docker-compose.override.yml found. The tuner can create one for environment overrides."
  fi

  cat <<'NOTE'

Safety notes:
- Run --dry-run first so you can review every planned change.
- The tuner creates timestamped .bak files before editing configs.
- Config changes only need a worldserver restart, not a rebuild.
- Keep your own server/database backups before tuning a server you care about.
NOTE
}

restore_latest() {
  require_server_dir

  local restored=0
  local config_backup=""
  local override=""
  local override_backup=""

  config_backup="$(find_latest_config_backup || true)"
  if [[ -n "$config_backup" ]]; then
    restore_backup_file "$config_backup"
    restored=1
  else
    warn "No worldserver.conf backup found."
  fi

  override="$(compose_override_file)"
  override_backup="$(latest_backup_for "$override" || true)"
  if [[ -n "$override_backup" ]]; then
    restore_backup_file "$override_backup"
    restored=1
  else
    warn "No docker-compose.override.yml backup found."
  fi

  [[ "$restored" == "1" ]] || die "No restorable backups were found in $SERVER_DIR."

  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for restored config changes to take effect."
  fi
}

main() {
  COMMAND_ARGS=()
  parse_args "$@"
  [[ -n "$COMMAND" ]] || { usage; exit 1; }

  case "$COMMAND" in
    list-presets) list_presets ;;
    list-performance) list_performance ;;
    doctor) doctor ;;
    apply-preset) apply_preset "${COMMAND_ARGS[@]}" ;;
    restore-latest) restore_latest ;;
    restart) restart_worldserver ;;
    *) die "Unknown command: $COMMAND" ;;
  esac
}

main "$@"
