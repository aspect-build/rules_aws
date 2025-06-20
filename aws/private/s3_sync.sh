#!/usr/bin/env bash
#
# Copyright 2022 Aspect Build Systems, Inc.
#
# s3 cp/sync script intended for use with s3_sync rule
# Copied from aspect-internal monorepo: bazel/release/copy_artifacts_to_bucket.sh

set -o errexit -o nounset -o pipefail

# Functions

msg() {
    if [[ $# -gt 0 ]]; then
        local msg="${1:-}"
        shift 1
        while (("$#")); do
            msg="${msg:-}"$'\n'"${1}"
            shift 1
        done
        echo "${msg}"
    else
        cat
    fi
}

warn() {
    if [[ $# -gt 0 ]]; then
        local msg="${1:-}"
        shift 1
        while (("$#")); do
            msg="${msg:-}"$'\n'"${1}"
            shift 1
        done
        echo >&2 "${msg}"
    else
        cat >&2
    fi
}

# Echos the provided message to stderr and exits with an error (1).
# shellcheck disable=SC2120
fail() {
    warn "$@"
    exit 1
}

# Print an error message and dump the usage/help for the utility.
# This function expects a get_usage function to be defined.
usage_error() {
    local msg="${1:-}"
    cmd=(fail)
    [[ -z "${msg:-}" ]] || cmd+=("${msg}" "")
    cmd+=("$(get_usage)")
    "${cmd[@]}"
}

show_usage() {
    get_usage
    exit 0
}

get_usage() {
    local utility
    utility="$(basename "${BASH_SOURCE[0]}")"
    cat <<-'EOF'
Copies the specified artifacts to an S3 bucket.

Usage:
EOF
    echo "${utility} [OPTION]... <artifact>..."
    cat <<-'EOF'
Options:
  --bucket                The name of the S3 bucket.
  --bucket_file <file>    The path to a file that contains the name of the S3 bucket.
  --[no]dry_run           Toggles whether the utility will run in dry-run mode.
                          Default: false

Arguments:
  <artifact>              The path to a file or directory which will be copied to the S3 bucket.
                          One or more artifacts can be specified.
EOF
}

s3_cp() {
    local src="${1}"
    local dst="${2}"

    if [[ "${dry_run}" == "false" ]]; then
        warn "Copying ${src} to ${dst}"
        "$aws" s3 cp "${src}" "${dst}"
    else
        warn "[DRY RUN] Would copy ${src} to ${dst}"
    fi
}

cp_artifact() {
    local artifact="${1}"
    local bucket="${2}"

    if [ -d "${artifact}" ]; then
        # Always flatten directories
        for f in "${artifact}"/*; do
            cp_artifact "${f}" "${bucket}"
        done
    else
        s3_cp "${artifact}" "${bucket}/$(basename "${artifact}")"
    fi
}

# Collect Args

dry_run=false
artifacts=()

while (("$#")); do
    case "${1}" in
    "--help")
        show_usage
        ;;
    "--bucket")
        bucket="${2}"
        shift 2
        ;;
    "--bucket_file")
        bucket_file="${2}"
        shift 2
        ;;
    "--destination_uri_file")
        destination_uri_file="${2}"
        shift 2
        ;;
    "--dry_run")
        dry_run="true"
        shift 1
        ;;
    "--nodry_run")
        dry_run="false"
        shift 1
        ;;
    "--role")
        role="${2}"
        shift 2
        ;;
    "--profile")
        export AWS_PROFILE="${2}"
        shift 2
        ;;
    --*)
        usage_error "Unrecognized flag. ${1}"
        ;;
    *)
        artifacts+=("${1}")
        shift 1
        ;;
    esac
done

# Process Arguments

[[ ${#artifacts[@]} -gt 0 ]] || usage_error "No artifacts were specified."

if [[ ! -z "${destination_uri_file:-}" ]]; then
    [[ ${#artifacts[@]} -eq 1 ]] || usage_error "destination_uri_file may be used only with a single artifact to copy"
else
    [[ -n "${bucket_file:-}" ]] && bucket="$(<"${bucket_file}")"

    [[ -n "${bucket:-}" ]] || usage_error "Missing value for 'bucket'."

    # Syntax sugar: append s3:// protocol to bucket URI if absent
    protocol="s3"

    [[ "${bucket}" =~ ^${protocol}:// ]] || bucket="${protocol}://${bucket}"
fi

[[ "${dry_run}" == "true" ]] &&
    warn <<-'EOF'
This is a dry run. No artifacts will be copied. To copy artifacts, run
with '--nodry_run'.
  bazel run --config=release //path/to/this:tool -- --nodry_run

EOF

# Check for Pre-requisites

# FIXME: doesn't work with SSO?
# if [[ "${dry_run}" == "false" ]]; then
#     # Ensure that the user's auth works

#     # shellcheck disable=SC2119
#     "$aws" sts get-caller-identity >/dev/null 2>&1 || fail <<-'EOF'
# It appears that your aws credentials are not configured properly. Please run
# 'aws configure' and try again.
# EOF
# fi

# shellcheck disable=SC2236
if [[ ! -z "${role:-}" && "${dry_run}" == "false" ]]; then
    msg "Assuming role '${role}' before sync"
    # shellcheck disable=SC2183,SC2046
    export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
        $("$aws" sts assume-role --role-arn "${role}" --role-session-name S3Sync --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text))

fi

# Copy artifacts

if [[ ! -z "${destination_uri_file:-}" ]]; then
    s3_cp "${artifacts[0]}" "$(<"${destination_uri_file}")"
else
    msg "Copying the following artifacts to ${bucket}:" "${artifacts[@]}" ""
    for artifact in "${artifacts[@]}"; do
        cp_artifact "${artifact}" "${bucket}"
    done
fi

# shellcheck disable=SC2236
if [[ ! -z "${role:-}" && "${dry_run}" == "false" ]]; then
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
fi
