#!/usr/bin/env bash
set -euo pipefail

# --- ANSI Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ️  ${NC}$*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠️  ${NC}$*"; }
error()   { echo -e "${RED}❌${NC} $*" >&2; }
debug()   { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${CYAN}🔍 DEBUG:${NC} $*"; }

VERBOSE="${VERBOSE:-false}"

# --- Validate inputs ---
debug "Validating inputs..."

if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  error "AWS credentials are required (aws-access-key-id, aws-secret-access-key)"
  exit 1
fi

if [[ -z "${S3_BUCKET:-}" ]]; then
  error "S3_BUCKET is required"
  exit 1
fi

debug "AWS credentials: provided"
debug "S3 bucket: $S3_BUCKET"
debug "Source dir: ${SOURCE_DIR:-dist}"
debug "Dry run: ${DRY_RUN:-false}"

# --- Detect compression availability ---
GZIP_CMD=""
BROTLI_CMD=""

if command -v gzip &>/dev/null && [[ "$GZIP" == "true" ]]; then
  GZIP_CMD="gzip -n9 -k"
  info "✅ gzip enabled"
fi

if command -v brotli &>/dev/null && [[ "$BROTLI" == "true" ]]; then
  BROTLI_CMD="brotli --quality=11"
  info "✅ brotli enabled (takes precedence over gzip)"
fi

# --- Configure AWS CLI ---
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

debug "AWS region: $AWS_DEFAULT_REGION"

# --- Determine s3 destination ---
S3_DEST="s3://${S3_BUCKET}"
[[ -n "${S3_PREFIX:-}" ]] && S3_DEST+="${S3_PREFIX}"

debug "S3 destination: $S3_DEST"

# Remove trailing slash from source
SOURCE_DIR="${SOURCE_DIR%/}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  error "Source directory '$SOURCE_DIR' does not exist"
  exit 1
fi

# --- Count files ---
FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')
info "📦 Processing $FILE_COUNT files in $SOURCE_DIR..."

# --- Build sync args ---
SYNC_ARGS=(
  "$SOURCE_DIR" "$S3_DEST"
  --region "$AWS_DEFAULT_REGION"
)

[[ "$DELETE_REMOVED" == "true" ]] && SYNC_ARGS+=(--delete)

if [[ -n "${EXTRA_ARGS:-}" ]]; then
  debug "Extra args: $EXTRA_ARGS"
  read -ra EXTRA_ARRAY <<< "$EXTRA_ARGS"
  SYNC_ARGS+=("${EXTRA_ARRAY[@]}")
fi

# --- Apply compression + cache headers ---
COMPRESSED_DIR=$(mktemp -d)
trap "rm -rf $COMPRESSED_DIR" EXIT

debug "Temp compressed dir: $COMPRESSED_DIR"

find "$SOURCE_DIR" -type f | while read -r file; do
  rel="${file#$SOURCE_DIR/}"
  dest_dir="$(dirname "$COMPRESSED_DIR/$rel")"
  mkdir -p "$dest_dir"

  base="${file##*.}"
  filename="${file##*/}"

  # Determine cache control
  cc="$CACHE_CONTROL"
  if [[ -n "${CACHE_ASSETS:-}" ]]; then
    if fnmatch "$CACHE_ASSETS" "$rel"; then
      cc="max-age=31536000, immutable"
      debug "  Immutable: $rel"
    fi
  fi

  # Compress if applicable
  if [[ -n "$BROTLI_CMD" ]]; then
    if [[ "$base" =~ ^(js|css|html|svg|xml|json|txt)$ ]]; then
      $BROTLI_CMD "$file" -o "$dest_dir/${filename}.br"
      debug "  Brotli: $rel -> ${rel}.br"
    fi
  elif [[ -n "$GZIP_CMD" ]]; then
    if [[ "$base" =~ ^(js|css|html|svg|xml|json|txt)$ ]]; then
      $GZIP_CMD "$file"
      debug "  Gzip: $rel -> ${rel}.gz"
    fi
  fi

  # Copy original
  cp "$file" "$dest_dir/$filename"
done

# --- Dry run ---
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  info "🔍 Dry run — files that would be synced:"
  aws s3 sync "${SYNC_ARGS[@]}" --dryrun
  success "Dry run complete (no changes made)"
  exit 0
fi

# --- Upload ---
info "🚀 Syncing $SOURCE_DIR → $S3_DEST"
aws s3 sync "${SYNC_ARGS[@]}" && success "Upload complete" || { error "Upload failed"; exit 1; }

# --- Set cache headers via s3 cp for compressed files ---
if [[ -n "$BROTLI_CMD" ]] || [[ -n "$GZIP_CMD" ]]; then
  info "🏷️  Setting cache headers..."
  for file in $(find "$COMPRESSED_DIR" -type f); do
    rel="${file#$COMPRESSED_DIR/}"
    content_type=""

    case "${file##*.}" in
      js)  content_type="application/javascript" ;;
      css) content_type="text/css" ;;
      html) content_type="text/html" ;;
      svg)  content_type="image/svg+xml" ;;
      xml)  content_type="application/xml" ;;
      json) content_type="application/json" ;;
    esac

    if [[ -n "$content_type" ]]; then
      debug "  Setting headers for: $rel (Content-Type: $content_type)"
      aws s3 cp "$file" "$S3_DEST/${rel}" \
        --region "$AWS_DEFAULT_REGION" \
        --content-type "$content_type" \
        --cache-control "$cc" \
        --metadata-directive REPLACE 2>/dev/null || warn "  Failed to set headers: $rel"
    fi
  done
fi

# --- CloudFront Invalidation ---
if [[ -n "${CF_DISTRIBUTION_ID:-}" ]]; then
  info "🌐 Creating CloudFront invalidation for ${CF_PATHS:-/*}..."
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "${CF_PATHS:-/*}" \
    --query 'Invalidation.Id' \
    --output text)

  info "⏳ Waiting for invalidation $INVALIDATION_ID..."
  aws cloudfront wait invalidation-completed \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --id "$INVALIDATION_ID"

  success "CloudFront invalidation complete: $INVALIDATION_ID"
  echo "::set-output name=invalidated-paths::${CF_PATHS:-/*}"
  {
    echo "invalidated-paths=${CF_PATHS:-/*}"
  } >> "$GITHUB_OUTPUT"
fi

# --- Output bucket URL ---
BUCKET_URL="https://${S3_BUCKET}.s3.${AWS_DEFAULT_REGION}.amazonaws.com"
[[ -n "${S3_PREFIX:-}" ]] && BUCKET_URL+="/${S3_PREFIX}"
echo "::set-output name=bucket-url::$BUCKET_URL"
{
  echo "bucket-url=$BUCKET_URL"
} >> "$GITHUB_OUTPUT"
success "🌍 Deployed to: $BUCKET_URL"
