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
HONOR_RATE=""
ARENA_RATE=""
REPAIR_COST=""
SKIP_CINEMATICS=""
REFERENCED_DROP_RATE=""
GROUP_DROP_RATE=""
INSTANCE_RESET_RATE=""

BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKED_UP_FILES=""
DRY_RUN_COMPOSE_OVERRIDE_ANNOUNCED=0
BASELINE_SNAPSHOT_NAME="baseline-before-wotlk-tuner"

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
  --honor N               Override honor rate.
  --arena N               Override arena point rate.
  --repair-cost N         Override repair cost rate.
  --skip-cinematics N     Override cinematic skipping: 0, 1, or 2.
  --referenced-drop N     Override referenced loot amount rate.
  --group-drop N          Override grouped loot amount rate.
  --instance-reset N      Override instance reset time rate.
  -h, --help              Show this help.

Commands:
  list-presets            Show available gameplay presets.
  show-preset NAME        Show a preset summary and config keys before applying.
  list-performance        Show performance profiles.
  doctor                  Check install layout and important settings.
  diagnose-rates          Show current tuning values in a compact report.
  apply-preset NAME       Apply a config preset.
  apply-custom            Apply only the override options you provide.
  apply-defaults          Apply conservative default values for common tuning keys.
  snapshot NAME           Save named config snapshots before experimenting.
  list-snapshots          Show named config snapshots.
  restore-snapshot NAME   Restore a named config snapshot.
  restore-baseline        Restore the automatic pre-tuner baseline snapshot.
  restore-latest          Restore latest tuner backups for config/compose files.
  restart                 Restart ac-worldserver with Docker Compose.

Presets:
  blizzlike               Conservative AzerothCore defaults for common tuning keys.
  solo-friendly           Lower-friction leveling for one or a few players.
  fast-leveling           Faster leveling without extreme loot inflation.
  alt-friendly            Easier alts, professions, starting money, and dual spec.
  loot-rich               More loot and money for casual private servers.
  reputation-friendly     Faster faction progress with modest XP support.
  casual-weekend          Relaxed 3x rates for short play sessions.
  profession-friendly     Faster professions and gathering with modest leveling.
  pvp-friendly            Boost honor, arena points, and battleground reputation.
  group-friendly          Friendly group/dungeon pacing and loot.
  hardcore-lite           Slower leveling, leaner economy, and higher repair cost.

Examples:
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
  ./scripts/wotlk-tuner.sh show-preset casual-weekend
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk diagnose-rates
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk snapshot before-fast-leveling
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --xp 2 --rep 3 --money 2
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 5 --restart
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-defaults --restart
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-baseline --restart
  ./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-snapshot before-fast-leveling
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
      --honor) HONOR_RATE="${2:-}"; shift 2 ;;
      --arena) ARENA_RATE="${2:-}"; shift 2 ;;
      --repair-cost) REPAIR_COST="${2:-}"; shift 2 ;;
      --skip-cinematics) SKIP_CINEMATICS="${2:-}"; shift 2 ;;
      --referenced-drop) REFERENCED_DROP_RATE="${2:-}"; shift 2 ;;
      --group-drop) GROUP_DROP_RATE="${2:-}"; shift 2 ;;
      --instance-reset) INSTANCE_RESET_RATE="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      list-presets|show-preset|list-performance|doctor|diagnose-rates|apply-preset|apply-custom|apply-defaults|snapshot|list-snapshots|restore-snapshot|restore-baseline|restore-latest|restart)
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

require_snapshot_name() {
  local name="$1"
  [[ -n "$name" ]] || die "Missing snapshot name."
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "Snapshot names may only use letters, numbers, dots, dashes, and underscores: $name"
  [[ "$name" != "." && "$name" != ".." ]] || die "Invalid snapshot name: $name"
}

conf_key_regex() {
  local key="$1"
  printf '%s\n' "$key" | sed 's/[.[\*^$()+?{}|\\]/\\&/g'
}

get_conf_value() {
  local file="$1"
  local key="$2"
  local key_regex
  key_regex="$(conf_key_regex "$key")"

  [[ -f "$file" ]] || return 1
  grep -E "^[[:space:]]*#?[[:space:]]*${key_regex}[[:space:]]*=" "$file" \
    | tail -1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//' || true
}

snapshot_root() {
  printf '%s\n' "$SERVER_DIR/.wotlk-tuner/snapshots"
}

snapshot_dir() {
  local name="$1"
  printf '%s/%s\n' "$(snapshot_root)" "$name"
}

baseline_snapshot_dir() {
  snapshot_dir "$BASELINE_SNAPSHOT_NAME"
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

apply_casual_weekend() {
  local config="$1"
  set_xp_rates "$config" "3"
  set_reputation_rates "$config" "3"
  set_drop_rates "$config" "2"
  set_money_rate "$config" "3"
  set_skill_rates "$config" "2"
  set_world_value "$config" "Rate.RepairCost" "0.5"
  set_world_value "$config" "MinDualSpecLevel" "20"
  set_world_value "$config" "SkipCinematics" "2"
}

apply_profession_friendly() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "1.5"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "5"
  set_world_value "$config" "SkillChance.Orange" "100"
  set_world_value "$config" "SkillChance.Yellow" "85"
  set_world_value "$config" "SkillChance.Green" "45"
  set_world_value "$config" "SkillChance.Grey" "0"
}

apply_pvp_friendly() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "1"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "1.5"
  set_world_value "$config" "Rate.Honor" "3"
  set_world_value "$config" "Rate.ArenaPoints" "3"
  set_world_value "$config" "Rate.Reputation.WSG" "3"
  set_world_value "$config" "Rate.Reputation.AB" "3"
  set_world_value "$config" "Rate.Reputation.AV" "3"
  set_world_value "$config" "MinDualSpecLevel" "20"
}

apply_group_friendly() {
  local config="$1"
  set_xp_rates "$config" "2"
  set_reputation_rates "$config" "2"
  set_drop_rates "$config" "2"
  set_money_rate "$config" "2"
  set_skill_rates "$config" "1.5"
  set_world_value "$config" "Rate.Drop.Item.ReferencedAmount" "1.25"
  set_world_value "$config" "Rate.Drop.Item.GroupAmount" "1.25"
  set_world_value "$config" "Rate.InstanceResetTime" "0.5"
  set_world_value "$config" "Rate.RepairCost" "0.5"
}

apply_hardcore_lite() {
  local config="$1"
  set_xp_rates "$config" "0.75"
  set_reputation_rates "$config" "1"
  set_drop_rates "$config" "0.75"
  set_money_rate "$config" "0.75"
  set_skill_rates "$config" "1"
  set_world_value "$config" "Rate.RepairCost" "1.5"
  set_world_value "$config" "MinDualSpecLevel" "40"
  set_world_value "$config" "SkipCinematics" "0"
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
  if [[ -n "$HONOR_RATE" ]]; then require_number "--honor" "$HONOR_RATE"; set_world_value "$config" "Rate.Honor" "$HONOR_RATE"; fi
  if [[ -n "$ARENA_RATE" ]]; then require_number "--arena" "$ARENA_RATE"; set_world_value "$config" "Rate.ArenaPoints" "$ARENA_RATE"; fi
  if [[ -n "$REPAIR_COST" ]]; then require_number "--repair-cost" "$REPAIR_COST"; set_world_value "$config" "Rate.RepairCost" "$REPAIR_COST"; fi
  if [[ -n "$SKIP_CINEMATICS" ]]; then require_integer "--skip-cinematics" "$SKIP_CINEMATICS"; set_world_value "$config" "SkipCinematics" "$SKIP_CINEMATICS"; fi
  if [[ -n "$REFERENCED_DROP_RATE" ]]; then require_number "--referenced-drop" "$REFERENCED_DROP_RATE"; set_world_value "$config" "Rate.Drop.Item.ReferencedAmount" "$REFERENCED_DROP_RATE"; fi
  if [[ -n "$GROUP_DROP_RATE" ]]; then require_number "--group-drop" "$GROUP_DROP_RATE"; set_world_value "$config" "Rate.Drop.Item.GroupAmount" "$GROUP_DROP_RATE"; fi
  if [[ -n "$INSTANCE_RESET_RATE" ]]; then require_number "--instance-reset" "$INSTANCE_RESET_RATE"; set_world_value "$config" "Rate.InstanceResetTime" "$INSTANCE_RESET_RATE"; fi
  apply_performance_profile "$config" "$PERFORMANCE"
}

has_custom_overrides() {
  [[ -n "$XP_RATE$KILL_XP_RATE$QUEST_XP_RATE$EXPLORE_XP_RATE$PET_XP_RATE$REP_RATE$DROP_RATE$MONEY_RATE$SKILL_RATE$START_LEVEL$START_MONEY$DUAL_SPEC_LEVEL$PERFORMANCE$HONOR_RATE$ARENA_RATE$REPAIR_COST$SKIP_CINEMATICS$REFERENCED_DROP_RATE$GROUP_DROP_RATE$INSTANCE_RESET_RATE" ]]
}

number_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit (a > b) ? 0 : 1 }'
}

number_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit (a < b) ? 0 : 1 }'
}

validate_config_values() {
  local config="$1"
  local max_level
  local start_level
  local start_heroic_level
  local referenced_amount
  local group_amount
  local key
  local value

  max_level="$(get_conf_value "$config" "MaxPlayerLevel")"
  start_level="$(get_conf_value "$config" "StartPlayerLevel")"
  start_heroic_level="$(get_conf_value "$config" "StartHeroicPlayerLevel")"

  if [[ -n "$max_level" && -n "$start_level" && "$max_level" =~ ^[0-9]+$ && "$start_level" =~ ^[0-9]+$ && "$start_level" -gt "$max_level" ]]; then
    warn "StartPlayerLevel ($start_level) is greater than MaxPlayerLevel ($max_level). New characters may fail or behave unexpectedly."
  fi

  if [[ -n "$max_level" && -n "$start_heroic_level" && "$max_level" =~ ^[0-9]+$ && "$start_heroic_level" =~ ^[0-9]+$ && "$start_heroic_level" -gt "$max_level" ]]; then
    warn "StartHeroicPlayerLevel ($start_heroic_level) is greater than MaxPlayerLevel ($max_level). Death Knight creation may behave unexpectedly."
  fi

  for key in Rate.XP.Kill Rate.XP.Quest Rate.XP.Explore Rate.Reputation.Gain Rate.Drop.Money Rate.Drop.Item.Rare SkillGain.Crafting; do
    value="$(get_conf_value "$config" "$key")"
    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] && number_gt "$value" "10"; then
      warn "$key is set to $value. Very high rates can distort progression and economy quickly."
    fi
  done

  referenced_amount="$(get_conf_value "$config" "Rate.Drop.Item.ReferencedAmount")"
  group_amount="$(get_conf_value "$config" "Rate.Drop.Item.GroupAmount")"
  if [[ "$referenced_amount" =~ ^[0-9]+([.][0-9]+)?$ ]] && { number_gt "$referenced_amount" "1.25" || number_lt "$referenced_amount" "1"; }; then
    warn "Rate.Drop.Item.ReferencedAmount is $referenced_amount. This affects referenced/boss loot behavior; test before relying on it."
  fi
  if [[ "$group_amount" =~ ^[0-9]+([.][0-9]+)?$ ]] && { number_gt "$group_amount" "1.25" || number_lt "$group_amount" "1"; }; then
    warn "Rate.Drop.Item.GroupAmount is $group_amount. This affects grouped loot behavior; test before relying on it."
  fi
}

create_snapshot_from_config() {
  local name="$1"
  local config="$2"
  local reason="$3"
  require_snapshot_name "$name"

  local dir
  dir="$(snapshot_dir "$name")"
  if [[ -e "$dir" ]]; then
    return 1
  fi

  local override
  override="$(compose_override_file)"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] create snapshot %q at %q\n' "$name" "$dir"
    printf '[dry-run] cp %q %q\n' "$config" "$dir/worldserver.conf"
    [[ -f "$override" ]] && printf '[dry-run] cp %q %q\n' "$override" "$dir/docker-compose.override.yml"
    return 0
  fi

  mkdir -p "$dir"
  cp "$config" "$dir/worldserver.conf"
  if [[ -f "$override" ]]; then
    cp "$override" "$dir/docker-compose.override.yml"
  fi
  {
    printf 'name=%s\n' "$name"
    printf 'created=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'reason=%s\n' "$reason"
    printf 'worldserver_config=%s\n' "$config"
    printf 'compose_override=%s\n' "$override"
  } > "$dir/manifest.txt"
  return 0
}

ensure_baseline_snapshot() {
  local config="$1"
  local dir
  dir="$(baseline_snapshot_dir)"

  if [[ -d "$dir" ]]; then
    return 0
  fi

  if create_snapshot_from_config "$BASELINE_SNAPSHOT_NAME" "$config" "Automatic snapshot before first wotlk-tuner apply command"; then
    log "Saved automatic baseline snapshot: $BASELINE_SNAPSHOT_NAME"
  fi
}

list_presets() {
  cat <<'PRESETS'
blizzlike             Conservative AzerothCore defaults for common tuning keys.
solo-friendly         2x XP/rep, modest drops, cheaper repairs, easier dual spec.
fast-leveling         5x XP with modest rep/money support for quick progression.
alt-friendly          3x XP, faster skills, starter money, and alt conveniences.
loot-rich             Higher item and money drops for casual private servers.
reputation-friendly   Faster faction gains with modest leveling support.
casual-weekend        Relaxed 3x pacing for short private-server sessions.
profession-friendly   Fast profession and gathering progression.
pvp-friendly          Boost honor, arena points, and battleground reputation.
group-friendly        Friendly dungeon/group loot and reset pacing.
hardcore-lite         Slower progression, leaner drops, and higher repair cost.
PRESETS
}

show_preset() {
  local preset="${1:-}"
  [[ -n "$preset" ]] || die "Missing preset name. Run list-presets."

  case "$preset" in
    blizzlike)
      cat <<'PRESET'
Preset: blizzlike
Intent: Return common tuning keys to conservative AzerothCore-style defaults.
Main values: 1x XP, 1x reputation, 1x drops, 1x money, 1x skills.
Convenience: level 1 starts, level 55 heroic starts, no cinematic skipping.
Touches: XP, reputation, drops, money, skills, honor, arena, repairs, starting values.
PRESET
      ;;
    solo-friendly)
      cat <<'PRESET'
Preset: solo-friendly
Intent: Lower-friction leveling for one player or a small private group.
Main values: 2x XP, 2x reputation, 1.5x drops, 2x money, 1.5x skills.
Convenience: cheaper repairs, level 30 dual spec, first cinematic only.
Touches: XP, reputation, drops, money, skills, repair cost, dual spec, cinematics.
PRESET
      ;;
    fast-leveling)
      cat <<'PRESET'
Preset: fast-leveling
Intent: Move through leveling quickly without extreme loot inflation.
Main values: 5x XP, 2x reputation, 1x drops, 2x money, 2x skills.
Convenience: cheaper repairs, level 20 dual spec, first cinematic only.
Touches: XP, reputation, drops, money, skills, repair cost, dual spec, cinematics.
PRESET
      ;;
    alt-friendly)
      cat <<'PRESET'
Preset: alt-friendly
Intent: Make repeated character creation and profession catch-up easier.
Main values: 3x XP, 2x reputation, 1.5x drops, 3x money, 3x skills.
Convenience: 10 gold starter money, level 20 dual spec, all cinematics skipped.
Touches: XP, reputation, drops, money, skills, starter money, dual spec, cinematics.
PRESET
      ;;
    loot-rich)
      cat <<'PRESET'
Preset: loot-rich
Intent: Increase item and money drops for casual private-server play.
Main values: 2x XP, 2x reputation, 3x common drops, 4x money, 2x skills.
Extra caution: changes referenced and grouped loot amounts to 1.5x.
Touches: XP, reputation, drops, money, skills, referenced loot, grouped loot, repairs.
PRESET
      ;;
    reputation-friendly)
      cat <<'PRESET'
Preset: reputation-friendly
Intent: Make faction progress much faster without huge loot changes.
Main values: 2x XP, 4x reputation, 1x drops, 2x money, 1.5x skills.
PvP rep: boosts WSG, AB, and AV reputation gains to 4x.
Touches: XP, reputation, battleground reputation, drops, money, skills.
PRESET
      ;;
    casual-weekend)
      cat <<'PRESET'
Preset: casual-weekend
Intent: Relaxed private-server pacing for short play sessions.
Main values: 3x XP, 3x reputation, 2x drops, 3x money, 2x skills.
Convenience: cheaper repairs, level 20 dual spec, all cinematics skipped.
Touches: XP, reputation, drops, money, skills, repair cost, dual spec, cinematics.
PRESET
      ;;
    profession-friendly)
      cat <<'PRESET'
Preset: profession-friendly
Intent: Speed up professions and gathering while keeping leveling moderate.
Main values: 2x XP, 2x reputation, 1.5x drops, 2x money, 5x skills.
Profession chances: orange 100, yellow 85, green 45, grey 0.
Touches: XP, reputation, drops, money, skill gains, skill-up chances.
PRESET
      ;;
    pvp-friendly)
      cat <<'PRESET'
Preset: pvp-friendly
Intent: Make battleground and arena rewards friendlier for private servers.
Main values: 2x XP, 2x reputation, 1x drops, 2x money, 1.5x skills.
PvP values: 3x honor, 3x arena points, 3x WSG/AB/AV reputation.
Touches: XP, reputation, honor, arena points, battleground reputation, dual spec.
PRESET
      ;;
    group-friendly)
      cat <<'PRESET'
Preset: group-friendly
Intent: Improve small-group and dungeon pacing without heavy source changes.
Main values: 2x XP, 2x reputation, 2x drops, 2x money, 1.5x skills.
Group values: 1.25x referenced/grouped loot and 0.5x instance reset time.
Touches: XP, reputation, drops, money, skills, group loot, instance reset, repairs.
PRESET
      ;;
    hardcore-lite)
      cat <<'PRESET'
Preset: hardcore-lite
Intent: Slower private-server progression without full punitive hardcore rules.
Main values: 0.75x XP, 1x reputation, 0.75x drops, 0.75x money, 1x skills.
Pressure: 1.5x repair cost, normal dual spec level, no cinematic skipping.
Touches: XP, reputation, drops, money, skills, repair cost, dual spec, cinematics.
PRESET
      ;;
    *) die "Unknown preset: $preset" ;;
  esac
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
  ensure_baseline_snapshot "$config"
  log "Applying preset '$preset' to: $config"

  case "$preset" in
    blizzlike) apply_blizzlike "$config" ;;
    solo-friendly) apply_solo_friendly "$config" ;;
    fast-leveling) apply_fast_leveling "$config" ;;
    alt-friendly) apply_alt_friendly "$config" ;;
    loot-rich) apply_loot_rich "$config" ;;
    reputation-friendly) apply_reputation_friendly "$config" ;;
    casual-weekend) apply_casual_weekend "$config" ;;
    profession-friendly) apply_profession_friendly "$config" ;;
    pvp-friendly) apply_pvp_friendly "$config" ;;
    group-friendly) apply_group_friendly "$config" ;;
    hardcore-lite) apply_hardcore_lite "$config" ;;
    *) die "Unknown preset: $preset" ;;
  esac

  apply_overrides "$config"
  validate_config_values "$config"

  log "Preset '$preset' complete."
  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for config changes to take effect."
  fi
}

apply_custom() {
  has_custom_overrides || die "apply-custom needs at least one override option, such as --xp 2, --rep 3, or --money 2."

  local config
  config="$(ensure_worldserver_config)"
  ensure_baseline_snapshot "$config"
  log "Applying custom overrides to: $config"

  apply_overrides "$config"
  validate_config_values "$config"

  log "Custom overrides complete."
  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for config changes to take effect."
  fi
}

apply_defaults() {
  local config
  config="$(ensure_worldserver_config)"
  ensure_baseline_snapshot "$config"
  log "Applying conservative default values to: $config"

  apply_blizzlike "$config"
  apply_overrides "$config"
  validate_config_values "$config"

  log "Default values complete."
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
    grep -E 'AC_RATE_|AC_SKILL_GAIN_|AC_SKILL_CHANCE_|AC_START_|AC_MIN_DUAL_SPEC_LEVEL|AC_SKIP_CINEMATICS|AC_GRID_UNLOAD|AC_MAP_UPDATE_|AC_NETWORK_|AC_THREAD_POOL|AC_VISIBILITY_' "$override" || true
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

print_value() {
  local config="$1"
  local label="$2"
  local key="$3"
  local value
  value="$(get_conf_value "$config" "$key")"
  printf '%-34s %-38s %s\n' "$label" "$key" "${value:-not set}"
}

diagnose_rates() {
  require_server_dir

  local config
  config="$(find_worldserver_config || true)"
  [[ -n "$config" ]] || die "No worldserver.conf found. Run doctor or apply a preset to create one from worldserver.conf.dist."

  printf 'Tuning report for: %s\n' "$config"
  printf '%-34s %-38s %s\n' "Setting" "Config key" "Value"
  printf '%-34s %-38s %s\n' "-------" "----------" "-----"
  print_value "$config" "Kill XP" "Rate.XP.Kill"
  print_value "$config" "Quest XP" "Rate.XP.Quest"
  print_value "$config" "Dungeon Finder Quest XP" "Rate.XP.Quest.DF"
  print_value "$config" "Explore XP" "Rate.XP.Explore"
  print_value "$config" "Pet XP" "Rate.XP.Pet"
  print_value "$config" "Reputation" "Rate.Reputation.Gain"
  print_value "$config" "Low-level kill reputation" "Rate.Reputation.LowLevel.Kill"
  print_value "$config" "Low-level quest reputation" "Rate.Reputation.LowLevel.Quest"
  print_value "$config" "WSG reputation" "Rate.Reputation.WSG"
  print_value "$config" "AB reputation" "Rate.Reputation.AB"
  print_value "$config" "AV reputation" "Rate.Reputation.AV"
  print_value "$config" "Poor item drops" "Rate.Drop.Item.Poor"
  print_value "$config" "Normal item drops" "Rate.Drop.Item.Normal"
  print_value "$config" "Uncommon item drops" "Rate.Drop.Item.Uncommon"
  print_value "$config" "Rare item drops" "Rate.Drop.Item.Rare"
  print_value "$config" "Epic item drops" "Rate.Drop.Item.Epic"
  print_value "$config" "Referenced loot amount" "Rate.Drop.Item.ReferencedAmount"
  print_value "$config" "Grouped loot amount" "Rate.Drop.Item.GroupAmount"
  print_value "$config" "Money drops" "Rate.Drop.Money"
  print_value "$config" "Crafting skill gain" "SkillGain.Crafting"
  print_value "$config" "Gathering skill gain" "SkillGain.Gathering"
  print_value "$config" "Weapon skill gain" "SkillGain.Weapon"
  print_value "$config" "Honor" "Rate.Honor"
  print_value "$config" "Arena points" "Rate.ArenaPoints"
  print_value "$config" "Repair cost" "Rate.RepairCost"
  print_value "$config" "Max player level" "MaxPlayerLevel"
  print_value "$config" "Start player level" "StartPlayerLevel"
  print_value "$config" "Start heroic player level" "StartHeroicPlayerLevel"
  print_value "$config" "Start player money" "StartPlayerMoney"
  print_value "$config" "Dual spec level" "MinDualSpecLevel"
  print_value "$config" "Skip cinematics" "SkipCinematics"
  print_value "$config" "Grid unload" "GridUnload"
  print_value "$config" "Map update threads" "MapUpdate.Threads"
  print_value "$config" "Network threads" "Network.Threads"
  print_value "$config" "Thread pool" "ThreadPool"
  print_value "$config" "Continent visibility" "Visibility.Distance.Continents"
  print_value "$config" "Instance visibility" "Visibility.Distance.Instances"
  validate_config_values "$config"
}

create_snapshot() {
  require_server_dir

  local name="${1:-}"
  require_snapshot_name "$name"

  local config
  config="$(find_worldserver_config || true)"
  [[ -n "$config" ]] || die "No worldserver.conf found. Run doctor or apply a preset to create one from worldserver.conf.dist."

  local dir
  dir="$(snapshot_dir "$name")"
  if [[ -e "$dir" ]]; then
    die "Snapshot already exists: $name. Use another name or remove $dir manually."
  fi

  create_snapshot_from_config "$name" "$config" "Manual snapshot"
  log "Created snapshot '$name' in: $dir"
}

list_snapshots() {
  require_server_dir

  local root
  root="$(snapshot_root)"
  if [[ ! -d "$root" ]]; then
    warn "No snapshots found."
    return 0
  fi

  local found=0
  local dir
  for dir in "$root"/*; do
    [[ -d "$dir" ]] || continue
    found=1
    printf '%s\n' "$(basename "$dir")"
  done

  [[ "$found" == "1" ]] || warn "No snapshots found."
}

restore_snapshot() {
  require_server_dir

  local name="${1:-}"
  require_snapshot_name "$name"

  local dir
  dir="$(snapshot_dir "$name")"
  [[ -d "$dir" ]] || die "Snapshot not found: $name"
  [[ -f "$dir/worldserver.conf" ]] || die "Snapshot is missing worldserver.conf: $dir"

  local config
  config="$(ensure_worldserver_config)"
  local override
  override="$(compose_override_file)"

  confirm_or_die "Restore snapshot '$name' to $SERVER_DIR?"

  backup_file_once "$config"
  if [[ -f "$override" ]]; then
    backup_file_once "$override"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cp %q %q\n' "$dir/worldserver.conf" "$config"
    if [[ -f "$dir/docker-compose.override.yml" ]]; then
      printf '[dry-run] cp %q %q\n' "$dir/docker-compose.override.yml" "$override"
    else
      printf '[dry-run] snapshot has no docker-compose.override.yml; leave %q unchanged\n' "$override"
    fi
  else
    cp "$dir/worldserver.conf" "$config"
    if [[ -f "$dir/docker-compose.override.yml" ]]; then
      cp "$dir/docker-compose.override.yml" "$override"
    fi
    log "Restored snapshot '$name'."
  fi

  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for restored config changes to take effect."
  fi
}

restore_baseline() {
  restore_snapshot "$BASELINE_SNAPSHOT_NAME"
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
    show-preset) show_preset "${COMMAND_ARGS[@]}" ;;
    list-performance) list_performance ;;
    doctor) doctor ;;
    diagnose-rates) diagnose_rates ;;
    apply-preset) apply_preset "${COMMAND_ARGS[@]}" ;;
    apply-custom) apply_custom ;;
    apply-defaults) apply_defaults ;;
    snapshot) create_snapshot "${COMMAND_ARGS[@]}" ;;
    list-snapshots) list_snapshots ;;
    restore-snapshot) restore_snapshot "${COMMAND_ARGS[@]}" ;;
    restore-baseline) restore_baseline ;;
    restore-latest) restore_latest ;;
    restart) restart_worldserver ;;
    *) die "Unknown command: $COMMAND" ;;
  esac
}

main "$@"
