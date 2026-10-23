#!/usr/bin/env bash
# Task Master bridge: translate between Task Master's tasks.json
# (https://github.com/eyaltoledano/claude-task-master) and Marge's epic.json.
#
#   taskmaster_to_epic <tasks.json> <title> <slug> [source-label]   → epic.json on stdout
#   epic_to_taskmaster <epic.json>                                  → tasks.json on stdout
#   taskmaster_default_title <tasks.json> <fallback>                → best-effort epic title
#
# Mapping (import):
#   int id n            → "T00n"            subtask id m under n → "T00n.m"
#   dependencies [int]  → ["T00x"]          subtask deps [m]     → ["T00n.m"]
#   testStrategy        → test_strategy
#   status in-progress  → in_progress       review → needs_human
#   status deferred/cancelled → blocked     anything unknown → pending
#
# Mapping (export) is the inverse. Marge-only statuses (needs_pivot,
# needs_human, failed) become Task Master `pending`, with a note appended
# to `details` so the information isn't lost.
#
# Both tagged (`{"master": {"tasks": [...]}}`) and legacy (`{"tasks": [...]}`)
# Task Master layouts are accepted on import; export always writes the
# tagged layout under the `master` tag.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# jq prelude shared by both directions.
_TM_JQ_LIB='
def tm_tasks:
  if (.tasks|type)=="array" then .tasks
  elif (.master.tasks|type)=="array" then .master.tasks
  else ([.[]? | select(type=="object" and (.tasks|type)=="array") | .tasks] | first // []) end;

def tm_meta:
  if (.metadata|type)=="object" then .metadata
  elif (.master.metadata|type)=="object" then .master.metadata
  else ([.[]? | select(type=="object" and (.metadata|type)=="object") | .metadata] | first // {}) end;

# 7 → "T007", 1234 → "T1234", "3" → "T003", "3.2" → "T003.2", "T003" → "T003"
def tid:
  if type=="number" then
    (tostring) as $s | "T" + (if ($s|length) < 3 then ("000" + $s)[-3:] else $s end)
  elif type=="string" then
    if test("^T[0-9]+(\\.[0-9]+)?$") then .
    elif test("^[0-9]+$") then (tonumber|tid)
    elif test("^[0-9]+\\.[0-9]+$") then (split(".") | (.[0]|tonumber|tid) + "." + .[1])
    else . end
  else tostring end;

# Dependency inside a ticket whose parent marge id is $pid ("" for top-level).
def dep_in($pid):
  if $pid == "" then tid
  elif type=="number" then $pid + "." + tostring
  elif type=="string" and test("^[0-9]+$") then $pid + "." + .
  else tid end;

def st_in:
  { "pending":"pending", "done":"done", "completed":"done",
    "in-progress":"in_progress", "in_progress":"in_progress",
    "review":"needs_human", "deferred":"blocked", "cancelled":"blocked",
    "blocked":"blocked", "needs_pivot":"needs_pivot",
    "needs_human":"needs_human", "failed":"failed" }[.] // "pending";

def prio_in:
  if . == null then null
  elif IN("high","medium","low") then . else "medium" end;

def ticket_in($pid):
  (if $pid == "" then (.id|tid) else ($pid + "." + (.id|tostring)) end) as $id
  | {
      id: $id,
      title: (.title // ("Task " + $id)),
      description: .description,
      details: .details,
      acceptance_criteria: (if (.acceptance_criteria|type)=="array" then .acceptance_criteria else null end),
      test_strategy: (.testStrategy // .test_strategy),
      priority: (.priority|prio_in),
      dependencies: ((.dependencies // []) | map(dep_in($pid))),
      status: ((.status // "pending")|tostring|st_in),
      pivots: 0,
      agent: .agent,
      subtasks: (if (.subtasks|type)=="array" and (.subtasks|length) > 0
                 then (.subtasks | map(ticket_in($id))) else null end)
    }
  | with_entries(select(.value != null));

# "T001" → 1, "T001.2" → 2
def tm_id: (split(".") | last | ltrimstr("T") | tonumber);

# Dependency string → Task Master dependency, relative to parent $pid.
def dep_out($pid):
  if type != "string" then .
  elif test("^T[0-9]+$") then (ltrimstr("T")|tonumber)
  elif test("^T[0-9]+\\.[0-9]+$") then
    (split(".")) as $p
    | if $pid != "" and $p[0] == $pid then ($p[1]|tonumber)
      else (($p[0]|ltrimstr("T")|tonumber|tostring) + "." + $p[1]) end
  else . end;

def st_out:
  { "pending":"pending", "done":"done", "in_progress":"in-progress",
    "blocked":"blocked", "needs_pivot":"pending", "needs_human":"pending",
    "failed":"pending" }[.] // "pending";

def st_note:
  if IN("needs_pivot","needs_human","failed")
  then "[marge] status was `" + . + "` at export; mapped to Task Master `pending`."
  else "" end;

def details_out:
  (.details // "") as $d | (.status|st_note) as $n
  | if $n == "" then $d elif $d == "" then $n else $d + "\n\n" + $n end;

def task_out($pid):
  {
    id: (.id|tm_id),
    title: .title,
    description: (.description // ""),
    details: details_out,
    testStrategy: (.test_strategy // ""),
    priority: (.priority // "medium"),
    dependencies: ((.dependencies // []) | map(dep_out($pid))),
    status: (.status|st_out)
  }
  + (if (.acceptance_criteria|type)=="array" then {acceptance_criteria} else {} end)
  + (if .agent != null then {agent} else {} end)
  + (if $pid == "" then
       {subtasks: (.id as $p | (.subtasks // []) | map(task_out($p)))}
     else {} end);
'

# taskmaster_default_title <tasks.json> <fallback>
taskmaster_default_title() {
    local src="$1" fallback="$2"
    jq -r --arg fb "$fallback" "$_TM_JQ_LIB"'
        tm_meta | (.marge.title // $fb)
    ' "$src"
}

# taskmaster_to_epic <tasks.json> <title> <slug> [source-label]
taskmaster_to_epic() {
    local src="$1" title="$2" slug="$3" label="${4:-$1}"
    jq --arg title "$title" --arg slug "$slug" --arg label "$label" \
       --arg ts "$(_ts)" --arg ver "$MARGE_VERSION" --arg ag "$MARGE_AGENT" \
       "$_TM_JQ_LIB"'
        (tm_meta) as $m
        | {
            meta: {
              id: $slug,
              title: $title,
              slug: $slug,
              description: ($m.marge.description // $m.description // ""),
              created: ($m.created // $ts),
              marge_version: $ver,
              agent: $ag,
              spec_sources: [$label]
            },
            tickets: (tm_tasks | map(ticket_in("")))
          }
    ' "$src"
}

# epic_to_taskmaster <epic.json>
epic_to_taskmaster() {
    local src="$1"
    jq --arg ts "$(_ts)" "$_TM_JQ_LIB"'
        {
          master: {
            tasks: (.tickets | map(task_out(""))),
            metadata: {
              created: (.meta.created // $ts),
              updated: $ts,
              description: (.meta.title // "Tasks for master context"),
              marge: {
                id: .meta.id,
                title: .meta.title,
                slug: .meta.slug,
                description: (.meta.description // ""),
                marge_version: .meta.marge_version
              }
            }
          }
        }
    ' "$src"
}
