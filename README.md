# AWS S3 Deploy Action

[![Build](https://github.com/yw13931835525-cyber/aws-s3-deploy-action/actions/workflows/test.yml/badge.svg)](https://github.com/yw13931835525-cyber/aws-s3-deploy-action/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)

Deploy static assets to AWS S3 with built-in compression, intelligent caching, and optional CloudFront invalidation.

## Features

- **gzip / brotli** compression for text-based assets
- **Intelligent cache headers** — immutable assets get `max-age=31536000, immutable`
- **Sync or replace** — uses `aws s3 sync` for efficient delta uploads
- **Delete removed files** — optionally purge stale S3 objects
- **CloudFront invalidation** — automatic cache busting after deploy
- **Dry-run mode** — preview what will be uploaded
- **Verbose logging** — debug mode for troubleshooting
- **Custom sync args** — pass extra `aws s3 sync` flags

## Installation

```yaml
- uses: actions/checkout@v4

- name: Deploy to S3
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
```

## Usage

### Basic Deploy

```yaml
- uses: actions/checkout@v4

- name: Deploy to S3
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-static-site'
    source-dir: 'dist'
```

### With CloudFront

```yaml
- name: Deploy with CloudFront
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-static-site'
    source-dir: 'dist'
    cloudfront-distribution-id: ${{ secrets.CF_DISTRIBUTION_ID }}
    cloudfront-paths: '/*'
    cache-control: 'max-age=3600'
```

### With Gzip + Immutable Cache

```yaml
- name: Deploy with gzip
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-site'
    source-dir: 'build'
    gzip: true
    cache-assets: '**/static/** **/*.chunk.js'
    cache-control: 'max-age=86400'
```

### Dry Run

Preview what would be uploaded without making changes:

```yaml
- name: Preview Deploy
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-site'
    source-dir: 'dist'
    dry-run: true
```

### Verbose Logging

Enable debug output for troubleshooting:

```yaml
- name: Deploy (verbose)
  uses: yw13931835525-cyber/aws-s3-deploy-action@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-site'
    source-dir: 'dist'
    verbose: true
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `aws-access-key-id` | ✅ | — | AWS Access Key ID |
| `aws-secret-access-key` | ✅ | — | AWS Secret Access Key |
| `aws-region` | ✅ | `us-east-1` | AWS region |
| `s3-bucket` | ✅ | — | S3 bucket name |
| `s3-prefix` | ❌ | — | S3 key prefix (e.g., `deploy/`) |
| `source-dir` | ❌ | `dist` | Local directory to upload |
| `delete-removed` | ❌ | `true` | Delete S3 files not in source |
| `gzip` | ❌ | `false` | Enable gzip compression |
| `brotli` | ❌ | `false` | Enable brotli (overrides gzip) |
| `cache-control` | ❌ | `max-age=31536000` | Default Cache-Control header |
| `cache-assets` | ❌ | — | Glob pattern for immutable assets |
| `cloudfront-distribution-id` | ❌ | — | CloudFront distribution ID |
| `cloudfront-paths` | ❌ | `/*` | Paths to invalidate |
| `dry-run` | ❌ | `false` | Simulate without uploading |
| `verbose` | ❌ | `false` | Enable verbose debug logging |
| `extra-args` | ❌ | — | Extra `aws s3 sync` arguments |

## Outputs

| Output | Description |
|--------|-------------|
| `bucket-url` | Full URL of deployed content |
| `invalidated-paths` | CloudFront invalidation paths |

## IAM Policy

The deploying IAM user needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Deploy",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-static-site/*",
        "arn:aws:s3:::my-static-site"
      ]
    },
    {
      "Sid": "CloudFrontInvalidation",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation"
      ],
      "Resource": "arn:aws:cloudfront::123456789:distribution/ABCDEF"
    }
  ]
}
```

## Troubleshooting

### Source directory not found

- Ensure `source-dir` points to a directory created by a previous step
- Add a `checkout` step before deploying

### CloudFront invalidation failing

- Verify the distribution ID is correct
- Check IAM permissions for `cloudfront:CreateInvalidation`
- CloudFront propagation can take 5-10 minutes

### Compression not working

- Ensure gzip/brotli binaries are available on the runner
- Only text-based assets (js, css, html, svg, xml, json, txt) are compressed

## License

MIT © yw13931835525-cyber
