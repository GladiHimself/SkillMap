# SkillMap — End-to-End Test Results

**Date:** 9 September 2026
**Tester:** Pranav Praveen
**Environment:** AWS `ap-south-1` (fresh `terraform apply`)
**Frontend:** `https://dd1e4ubbzm74h.cloudfront.net`

---

## Test Summary

| # | Test | Result | Time | Notes |
|---|------|--------|------|-------|
| 1 | Post job — AI extracts skills | ✅ Pass | ~2s | Llama 3 via Bedrock |
| 2 | Upload resume via UI (pre-signed URL) | ✅ Pass | <1s | Direct browser → S3, backend never touches the file |
| 3 | Lambda pipeline processes resume | ✅ Pass | 5.2s | S3 → SQS → Lambda → Bedrock → RDS |
| 4 | Resume record updated (not duplicated) | ✅ Pass | — | `rows_updated: 1` |
| 5 | Match score calculated | ✅ Pass | <1s | Bajrang → Platform Engineer: **66.7%** |
| 6 | SNS match email delivered | ✅ Pass | ~15s | Received at subscribed address |
| 7 | Correlation ID traced end-to-end | ✅ Pass | — | Single ID across Spring Boot → S3 → Lambda |
| 8 | CloudWatch dashboard reflects activity | ✅ Pass | — | Lambda, ECS, SQS widgets all populated |

---

## Architecture Confirmed Working

```
Browser (HTTPS)
    ↓
CloudFront
    ├── /jobs /resumes /match  → S3 (React static build)
    └── /api/*                 → ALB → ECS Fargate → RDS PostgreSQL

Resume upload path:
Browser → pre-signed URL → S3 → SQS → Lambda
                                        ├── Bedrock (Llama 3) — skill extraction
                                        ├── RDS — persist extracted skills
                                        └── SNS — email notification
```

---

## Sample Correlation ID Trace

A single resume upload, traced by one correlation ID across services:

```
req-466de8f5  Processing resume            (Lambda)
req-466de8f5  Reading from S3              (Lambda)
req-466de8f5  Calling Bedrock Llama 3      (Lambda)
req-466de8f5  Bedrock response received    (Lambda)
req-466de8f5  Saving extracted data to RDS (Lambda)
req-466de8f5  Table check complete         (Lambda)
req-466de8f5  RDS updated successfully     (Lambda) rows_updated: 1
req-466de8f5  SNS notification published   (Lambda)
req-466de8f5  Resume processed successfully(Lambda)
```

The ID originates in Spring Boot (`CorrelationIdFilter`), is attached to the S3
object as custom metadata during the pre-signed upload, and is read back by
Lambda via `head_object` — allowing a single CloudWatch search to reconstruct
the full journey.

---

## Sample AI Extraction Output

**Job description input:**
> "We are hiring a Platform Engineer with strong AWS, Kubernetes, and Terraform
> experience. Must know CI/CD pipelines and have hands-on Docker skills.
> PostgreSQL knowledge is a plus."

**Extracted skills:**
```
AWS, Kubernetes, Terraform, CI/CD, Docker, PostgreSQL
```

**Resume extraction output:**
```json
{
  "skills": ["Java", "Spring Boot", "AWS", "PostgreSQL", "Docker", "Terraform", "React"],
  "years_experience": 3,
  "education": "BSc Computer Science"
}
```

---

## Bugs Found and Fixed During This Test

The end-to-end run surfaced six real defects that individual component testing
had missed:

### 1. Missing `wget` in the container image
ECS health checks used `wget` but the `amazoncorretto:21-al2023-jdk` base image
doesn't include it, so every health check failed immediately and ECS killed the
task in a continuous restart loop.
**Fix:** `RUN dnf install -y wget && dnf clean all` in the Dockerfile.

### 2. ECS task role missing Bedrock permission
Only the Lambda role had `bedrock:InvokeModel`. Job posting silently returned
empty skills because the Spring Boot service was denied.
**Fix:** New `ecs_bedrock_access` IAM policy attached to the ECS task role.

### 3. Incorrect Llama 3 prompt format
Mistral-style `[INST]` tags were being echoed back verbatim as the extracted
skill list. Llama 3 uses its own `<|begin_of_text|>` / `<|start_header_id|>`
chat template.
**Fix:** Switched to the native Llama 3 prompt format, `temperature: 0.0`,
`max_gen_len: 100`, plus post-processing to strip special tokens.

### 4. Missing S3 CORS configuration
Browser uploads to the pre-signed URL were blocked — the S3 bucket had no CORS
rule allowing cross-origin `PUT` from the CloudFront domain.
**Fix:** Added `aws_s3_bucket_cors_configuration` to the resumes bucket.

### 5. `s3Key` silently dropped by the request DTO
`ResumeRequestDTO` had no `s3Key` field, so Spring Boot ignored it. The database
column stayed null, Lambda couldn't match the record, and inserted a duplicate
row with placeholder data on every upload.
**Fix:** Added `s3Key` to the DTO and passed it through in `ResumeService`.

### 6. ECS task role missing SNS publish permission
Match scores calculated correctly but the notification email never sent —
`SNS:Publish` was denied for the ECS task role.
**Fix:** New `ecs_sns_access` IAM policy attached to the ECS task role.

---

## Observations

- **Cold start:** Lambda init adds ~400–500ms on first invocation after idle.
- **Spring Boot startup:** ~41s in ECS Fargate, which is why the health check
  `startPeriod` is set to 90s and the ECS service grace period to 120s.
- **Bedrock latency:** ~4s per Llama 3 call for resume parsing, ~2s for the
  shorter job description prompt.
- **Total pipeline time:** ~5.2s from S3 upload event to SNS publish.

---

## Known Limitations

- Match scoring uses keyword overlap, not semantic similarity — "Node.js" and
  "JavaScript" are treated as unrelated skills. Vector embeddings would be the
  natural next upgrade.
- Lambda's insert-fallback still uses a hardcoded placeholder name/email when no
  matching resume record exists. Acceptable for CLI-based testing but should be
  removed or made explicit before any real use.
- Every `terraform destroy` / `apply` cycle regenerates the GitHub Actions IAM
  access keys and resets SNS email subscriptions to `PendingConfirmation`, both
  of which must be manually refreshed.

---

## Conclusion

All eight test cases passed. The complete user journey — recruiter posts a job,
candidate uploads a resume, AI extracts skills from both, system calculates a
match score, candidate receives an email — works end to end on live AWS
infrastructure, fully provisioned via Terraform and deployed via GitHub Actions.
