# AWS S3 Deploy Action

Deploy static assets to AWS S3 with built-in compression, intelligent caching, and optional CloudFront invalidation.

## Features

- **gzip / brotli** compression for text-based assets
- **Intelligent cache headers** — immutable assets get `max-age=31536000, immutable`
- **Sync or replace** — uses `aws s3 sync` for efficient delta uploads
- **Delete removed files** — optionally purge stale S3 objects
- **CloudFront invalidation** — automatic cache busting after deploy
- **Dry-run mode** — preview what will be uploaded
- **Custom sync args** — pass extra `aws s3 sync` flags

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

## License

MIT © yw13931835525-cyber
