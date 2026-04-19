#!/usr/bin/env bash
set -euo pipefail

# --- Validate ---
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "::error::AWS credentials are required"
  exit 1
fi

if [[ -z "${S3_BUCKET:-}" ]]; then
  echo "::error::S3_BUCKET is required"
  exit 1
fi

# --- Detect compression availability ---
GZIP_CMD=""
BROTLI_CMD=""

if command -v gzip &>/dev/null && [[ "$GZIP" == "true" ]]; then
  GZIP_CMD="gzip -n9 -k"
  echo "✅ gzip enabled"
fi

if command -v brotli &>/dev/null && [[ "$BROTLI" == "true" ]]; then
  BROTLI_CMD="brotli --quality=11"
  echo "✅ brotli enabled"
fi

# --- Configure AWS CLI ---
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

# --- Determine s3 destination ---
S3_DEST="s3://${S3_BUCKET}"
[[ -n "${S3_PREFIX:-}" ]] && S3_DEST+="${S3_PREFIX}"

# Remove trailing slash from source
SOURCE_DIR="${SOURCE_DIR%/}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "::error::Source directory '$SOURCE_DIR' does not exist"
  exit 1
fi

# --- Build sync args ---
SYNC_ARGS=(
  "$SOURCE_DIR" "$S3_DEST"
  --region "$AWS_DEFAULT_REGION"
)

[[ "$DELETE_REMOVED" == "true" ]] && SYNC_ARGS+=(--delete)

if [[ -n "${EXTRA_ARGS:-}" ]]; then
  read -ra EXTRA_ARRAY <<< "$EXTRA_ARGS"
  SYNC_ARGS+=("${EXTRA_ARRAY[@]}")
fi

# --- Apply compression + cache headers ---
COMPRESSED_DIR=$(mktemp -d)
trap "rm -rf $COMPRESSED_DIR" EXIT

echo "📦 Processing files in $SOURCE_DIR..."

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
    fi
  fi

  # Compress if applicable
  if [[ -n "$BROTLI_CMD" ]]; then
    if [[ "$base" =~ ^(js|css|html|svg|xml|json|txt)$ ]]; then
      $BROTLI_CMD "$file" -o "$dest_dir/${filename}.br"
      echo "::debug::Brotli: $rel -> ${rel}.br"
    fi
  elif [[ -n "$GZIP_CMD" ]]; then
    if [[ "$base" =~ ^(js|css|html|svg|xml|json|txt)$ ]]; then
      $GZIP_CMD "$file"
      echo "::debug::Gzip: $rel -> ${rel}.gz"
    fi
  fi

  # Copy original
  cp "$file" "$dest_dir/$filename"
done

# --- Dry run ---
if [[ "$DRY_RUN" == "true" ]]; then
  echo "🔍 Dry run — files that would be synced:"
  aws s3 sync "${SYNC_ARGS[@]}" --dryrun
  exit 0
fi

# --- Upload ---
echo "🚀 Syncing $SOURCE_DIR → $S3_DEST"
aws s3 sync "${SYNC_ARGS[@]}"

echo "✅ Deployment complete"

# --- Set cache headers via s3 cp for compressed files ---
if [[ -n "$BROTLI_CMD" ]] || [[ -n "$GZIP_CMD" ]]; then
  echo "🏷️  Setting cache headers..."
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
      aws s3 cp "$file" "$S3_DEST/${rel}" \
        --region "$AWS_DEFAULT_REGION" \
        --content-type "$content_type" \
        --cache-control "$cc" \
        --metadata-directive REPLACE 2>/dev/null || true
    fi
  done
fi

# --- CloudFront Invalidation ---
if [[ -n "${CF_DISTRIBUTION_ID:-}" ]]; then
  echo "🌐 Creating CloudFront invalidation for ${CF_PATHS:-/*}..."
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "${CF_PATHS:-/*}" \
    --query 'Invalidation.Id' \
    --output text)

  echo "⏳ Waiting for invalidation $INVALIDATION_ID..."
  aws cloudfront wait invalidation-completed \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --id "$INVALIDATION_ID"

  echo "✅ CloudFront invalidation complete: $INVALIDATION_ID"
  echo "::set-output name=invalidated-paths::${CF_PATHS:-/*}"
fi

# --- Output bucket URL ---
BUCKET_URL="https://${S3_BUCKET}.s3.${AWS_DEFAULT_REGION}.amazonaws.com"
[[ -n "${S3_PREFIX:-}" ]] && BUCKET_URL+="/${S3_PREFIX}"
echo "::set-output name=bucket-url::$BUCKET_URL"
echo "🌍 Deployed to: $BUCKET_URL"
