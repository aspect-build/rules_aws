#!/usr/bin/env bash
#
# Copyright 2022 Aspect Build Systems, Inc.
#
# s3 cp/sync script intended for use with s3_sync rule

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
  --sync_archive          Rather than copy an archive file, unpack it and sync the contents.

Arguments:
  <artifact>              The path to a file which will be copied to the S3 bucket.
                          One or more artifacts can be specified.
EOF
}

cp_artifact() {
    local artifact="${1}"
    local bucket="${2}"

    if [ -d "${artifact}" ]; then
        # Always flatten directories
        for f in "${artifact}"/*; do
            cp_artifact "${f}" "${bucket}"
        done
    elif [[ "${sync_archive:-}" ]]; then
        if [[ "${dry_run}" == "false" ]]; then
            warn "Syncing ${artifact} to ${bucket}"
            local untar
            untar=$(mktemp -d)
            tar -xf "${artifact}" -C "${untar}"
            # shellcheck disable=SC2154
            "$aws" s3 sync "${untar}" "${bucket}"
        else
            warn "[DRY RUN] Would sync ${artifact} to ${bucket}"
        fi
    else
        local dst
        dst="${bucket}/$(basename "${artifact}")"
        if [[ "${dry_run}" == "false" ]]; then
            warn "Copying ${artifact} to ${dst}"
            "$aws" s3 cp "${artifact}" "${dst}"
        else
            warn "[DRY RUN] Would copy ${artifact} to ${dst}"
        fi
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
    "--dry_run")
        dry_run="true"
        shift 1
        ;;
    "--nodry_run")
        dry_run="false"
        shift 1
        ;;
    "--sync_archive")
        sync_archive="true"
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

[[ -n "${bucket_file:-}" ]] && bucket="$(<"${bucket_file}")"

[[ -n "${bucket:-}" ]] || usage_error "Missing value for 'bucket'."

protocol="s3"

[[ "${bucket}" =~ ^${protocol}:// ]] || bucket="${protocol}://${bucket}"

[[ ${#artifacts[@]} -gt 0 ]] || usage_error "No artifacts were specified."

[[ "${dry_run}" == "true" ]] &&
    warn <<-'EOF'
This is a dry run. No artifacts will be copied.  To copy artifacts, run
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
        $("$aws" sts assume-role --role-arn "${role}" --role-session-name S3Releaser --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --output text))

fi

# Copy artifacts

msg "Copying the following artifacts to ${bucket}:" "${artifacts[@]}" ""

for artifact in "${artifacts[@]}"; do
    cp_artifact "${artifact}" "${bucket}"
done

# shellcheck disable=SC2236
if [[ ! -z "${role:-}" && "${dry_run}" == "false" ]]; then
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
fi
