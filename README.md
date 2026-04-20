# ☁️ AWS S3 Deploy Action

[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/yw13931835525-cyber/aws-s3-deploy-action)](https://github.com/yw13931835525-cyber/aws-s3-deploy-action/stargazers)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen.svg)](CONTRIBUTING.md)

## What It Does

Deploy static assets to AWS S3 with built-in gzip/brotli compression, intelligent cache headers, and optional CloudFront invalidation. Ships only changed files using `aws s3 sync` — fast, efficient, and production-ready.

## Features

- ✅ **gzip / brotli compression** — for text-based assets (js, css, html, svg, etc.)
- ✅ **Intelligent cache headers** — immutable assets get `max-age=31536000, immutable`
- ✅ **Delta sync** — uses `aws s3 sync` for efficient uploads of only changed files
- ✅ **Delete removed files** — optionally purge stale S3 objects
- ✅ **CloudFront invalidation** — automatic cache busting after deploy
- ✅ **Dry-run mode** — preview what will be uploaded without making changes
- ✅ **Verbose logging** — debug mode for troubleshooting
- ✅ **Custom sync args** — pass extra `aws s3 sync` flags

## Quick Start

```yaml
- uses: actions/checkout@v4

- name: Deploy to S3
  uses: yw13931835525-cyber/aws-s3-deploy-action@main
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: 'my-static-site'
    source-dir: 'dist'
```

## Use Cases

### Static Website with CloudFront
Deploy your static site and automatically invalidate CloudFront cache so visitors see the new content immediately.

```yaml
- name: Deploy with CloudFront
  uses: yw13931835525-cyber/aws-s3-deploy-action@main
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: ${{ secrets.S3_BUCKET }}
    source-dir: 'dist'
    cloudfront-distribution-id: ${{ secrets.CF_DISTRIBUTION_ID }}
    cloudfront-paths: '/*'
    gzip: true
```

### SPA with Immutable Asset Caching
Deploy a single-page app with aggressive caching for hashed asset filenames.

```yaml
- name: Deploy SPA
  uses: yw13931835525-cyber/aws-s3-deploy-action@main
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: 'us-east-1'
    s3-bucket: ${{ secrets.S3_BUCKET }}
    source-dir: 'build'
    gzip: true
    cache-assets: '**/static/** **/*.chunk.js'
    cache-control: 'max-age=31536000, immutable'
```

## Configuration

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `aws-access-key-id` | **Yes** | — | AWS Access Key ID |
| `aws-secret-access-key` | **Yes** | — | AWS Secret Access Key |
| `aws-region` | **Yes** | `us-east-1` | AWS region |
| `s3-bucket` | **Yes** | — | S3 bucket name |
| `s3-prefix` | No | — | S3 key prefix (e.g., `deploy/`) |
| `source-dir` | No | `dist` | Local directory to upload |
| `delete-removed` | No | `true` | Delete S3 files not in source |
| `gzip` | No | `false` | Enable gzip compression |
| `brotli` | No | `false` | Enable brotli (overrides gzip) |
| `cache-control` | No | `max-age=31536000` | Default Cache-Control header |
| `cache-assets` | No | — | Glob pattern for immutable assets |
| `cloudfront-distribution-id` | No | — | CloudFront distribution ID |
| `cloudfront-paths` | No | `/*` | Paths to invalidate |
| `dry-run` | No | `false` | Simulate without uploading |
| `verbose` | No | `false` | Enable verbose debug logging |
| `extra-args` | No | — | Extra `aws s3 sync` arguments |

## Outputs

| Output | Description |
|--------|-------------|
| `bucket-url` | Full URL of deployed content |
| `invalidated-paths` | Number of CloudFront paths invalidated |

## IAM Policy

Your IAM user needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Deploy",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-static-site/*", "arn:aws:s3:::my-static-site"]
    },
    {
      "Sid": "CloudFrontInvalidation",
      "Effect": "Allow",
      "Action": ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"],
      "Resource": "arn:aws:cloudfront::123456789:distribution/ABCDEF"
    }
  ]
}
```

## Pro Version

Get advanced features:
- Incremental deploys with fine-grained invalidation
- Multi-environment deployments (staging, production)
- Priority support

👉 [Get Pro License](https://hbhsgr.com)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Source directory not found | Ensure `source-dir` points to a directory created by a previous step |
| CloudFront invalidation failing | Verify distribution ID and IAM permissions |
| Compression not working | Only text-based assets (js, css, html, svg, xml, json, txt) are compressed |

## License

MIT License - Free for personal and commercial use

## Contributing

Contributions welcome! Please read our Contributing Guidelines.
