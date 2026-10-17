# Shared POSIX-Awk validation and parent-first profile capability resolution.
# Successful output is one stable colon-separated capability list.

function fail(message) {
    print "[mantle:error] profiles: " message
    failed = 1
    exit 64
}

function check_list(value, label, pieces, total, position, seen) {
    if (value == "-") return
    if (value == "" || value ~ /^:|:$|::/) fail("invalid " label " list")
    total = split(value, pieces, ":")
    for (position = 1; position <= total; position++) {
        if (label == "parent" && !(pieces[position] in allowed)) fail("unknown parent name")
        if (label == "capability" && !(pieces[position] in allowed_caps)) fail("unknown capability name")
        if (seen[pieces[position]]++) fail("duplicate " label " name")
    }
}

function validate(name, depth, pieces, total, position) {
    if (!(name in parents)) fail("missing parent profile")
    if (depth > 64) fail("inheritance depth exceeds limit")
    if (visiting[name] == 1) fail("inheritance cycle detected")
    if (visiting[name] == 2) return
    visiting[name] = 1
    if (parents[name] != "-") {
        total = split(parents[name], pieces, ":")
        for (position = 1; position <= total; position++) validate(pieces[position], depth + 1)
    }
    visiting[name] = 2
}

function resolve(name, pieces, total, position, names, count, cap_index) {
    if (resolved[name]++) return
    if (parents[name] != "-") {
        total = split(parents[name], pieces, ":")
        for (position = 1; position <= total; position++) resolve(pieces[position])
    }
    if (capabilities[name] != "-") {
        count = split(capabilities[name], names, ":")
        for (cap_index = 1; cap_index <= count; cap_index++) {
            if (!emitted[names[cap_index]]++) {
                result = result (result == "" ? "" : ":") names[cap_index]
            }
        }
    }
}

BEGIN {
    FS = "\t"
    allowed["core"] = allowed["interactive"] = allowed["workstation"] = 1
    allowed["container"] = allowed["ci"] = allowed["full"] = 1
    allowed_caps["core"] = allowed_caps["interactive"] = allowed_caps["tooling"] = 1
    allowed_caps["workstation"] = allowed_caps["container"] = allowed_caps["ci"] = 1
    if (!(selected in allowed)) fail("unknown selected profile")
}

NR == 1 {
    if ($0 != "profile\tparents\tcapabilities") fail("invalid manifest header")
    next
}

{
    if (NR > 65 || NF != 3 || !($1 in allowed)) fail("invalid manifest row")
    if ($1 in parents) fail("duplicate profile")
    check_list($2, "parent")
    check_list($3, "capability")
    parents[$1] = $2
    capabilities[$1] = $3
    order[++count_profiles] = $1
}

END {
    if (failed) exit 64
    if (NR == 0 || count_profiles != 6) fail("all six profiles are required")
    for (position = 1; position <= count_profiles; position++) validate(order[position], 0)
    resolve(selected)
    print result
}
