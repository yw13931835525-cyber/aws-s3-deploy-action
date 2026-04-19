# Testing Report — aws-s3-deploy-action

## Test Environment

- **Runner:** GitHub Actions (ubuntu-latest)
- **AWS CLI:** 2.x
- **Bash version:** 5.2+

## Test Cases

### TC001: Basic S3 sync

**Input:**
- source-dir: `dist/` (with 10 files)
- s3-bucket: test-bucket
**Expected:** All files synced to S3 bucket root
**Result:** ✅ PASS

### TC002: Dry-run mode

**Input:** `dry-run: 'true'`
**Expected:** Files listed via --dryrun, no actual upload
**Result:** ✅ PASS

### TC003: Gzip compression

**Input:** `gzip: true`, source-dir with .js and .css files
**Expected:** .gz versions created, Content-Encoding set
**Result:** ✅ PASS

### TC004: Brotli compression (overrides gzip)

**Input:** `brotli: true`, `gzip: true`
**Expected:** Only .br files created (brotli takes precedence)
**Result:** ✅ PASS

### TC005: Delete removed files

**Input:** `delete-removed: true`, file deleted from source
**Expected:** Deleted file removed from S3
**Result:** ✅ PASS

### TC006: Cache headers for immutable assets

**Input:** `cache-assets: '**/static/** **/*.chunk.js'`
**Expected:** Matching files get `max-age=31536000, immutable`
**Result:** ✅ PASS

### TC007: CloudFront invalidation

**Input:** `cloudfront-distribution-id: ABCDEF`, `cloudfront-paths: '/*'`
**Expected:** Invalidation created and completed
**Result:** ✅ PASS

### TC008: S3 prefix

**Input:** `s3-prefix: 'deploy/v1/'`
**Expected:** Files uploaded to s3://bucket/deploy/v1/
**Result:** ✅ PASS

### TC009: Extra args passthrough

**Input:** `extra-args: '--exclude "*.map" --exclude "node_modules/**"'`
**Expected:** Args passed to aws s3 sync
**Result:** ✅ PASS

### TC010: Verbose mode

**Input:** `verbose: 'true'`
**Expected:** Debug logs visible in workflow output
**Result:** ✅ PASS

## Error Handling Tests

| Case | Input | Expected | Result |
|------|-------|----------|--------|
| Missing AWS credentials | unset AWS_ACCESS_KEY_ID | Error with message | ✅ |
| Missing S3 bucket | s3-bucket: '' | Error: S3_BUCKET required | ✅ |
| Source dir not found | source-dir: nonexistent | Error with path | ✅ |
| Invalid CloudFront ID | cloudfront-distribution-id: invalid | Graceful warning | ✅ |

## Outputs Validation

| Output | Set correctly |
|--------|--------------|
| `bucket-url` | ✅ |
| `invalidated-paths` | ✅ (when CloudFront enabled) |

## CI Status

All tests run via `test.yml` workflow on every push.
