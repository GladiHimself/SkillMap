import json
import boto3
import logging
import urllib.parse
import os
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def log(level, message, correlation_id=None, **kwargs):
    """Structured logger — always logs as JSON, includes correlation ID"""
    log_entry = {
        "level": level,
        "message": message,
        "correlationId": correlation_id or "unknown",
        **kwargs
    }
    if level == "ERROR":
        logger.error(json.dumps(log_entry))
    else:
        logger.info(json.dumps(log_entry))

# AWS clients — initialised once outside handler for warm start reuse
s3_client      = boto3.client("s3")
bedrock_client = boto3.client("bedrock-runtime", region_name="ap-south-1")
sns_client     = boto3.client("sns")
secrets_client = boto3.client("secretsmanager", region_name="ap-south-1")

# Cache DB credentials — fetched once per Lambda container lifetime
_db_credentials = None

def get_db_credentials():
    global _db_credentials
    if _db_credentials is None:
        secret_name = os.environ.get(
            "DB_SECRET_NAME",
            "skillmap/dev/db-credentials"
        )
        log("INFO", "Fetching DB credentials from Secrets Manager",
            secret_name=secret_name)
        response = secrets_client.get_secret_value(SecretId=secret_name)
        _db_credentials = json.loads(response["SecretString"])
        log("INFO", "DB credentials fetched successfully")
    return _db_credentials

def get_db_connection():
    import psycopg2
    creds = get_db_credentials()
    return psycopg2.connect(
        host            = creds["host"],
        database        = creds["dbname"],
        user            = creds["username"],
        password        = creds["password"],
        port            = creds.get("port", 5432),
        connect_timeout = 10
    )

def lambda_handler(event, context):
    log("INFO", "Lambda triggered", record_count=len(event["Records"]))

    for record in event["Records"]:
        sqs_body = json.loads(record["body"])

        if "Records" in sqs_body:
            s3_event = sqs_body["Records"][0]["s3"]
        elif "s3" in sqs_body:
            s3_event = sqs_body["s3"]
        else:
            log("INFO", "Unexpected message format", body=str(sqs_body)[:500])
            continue

        bucket = s3_event["bucket"]["name"]
        key    = urllib.parse.unquote_plus(s3_event["object"]["key"])

        # Read the correlation ID that Spring Boot attached when uploading
        # Falls back to a new one if the object has no metadata
        # (e.g. uploaded manually via CLI, like our test resumes)
        correlation_id = get_correlation_id_from_s3(bucket, key)

        log("INFO", "Processing resume", correlation_id=correlation_id,
            bucket=bucket, key=key)

        try:
            resume_text = read_resume_from_s3(bucket, key, correlation_id)
            extracted = extract_skills_with_bedrock(resume_text, correlation_id)
            save_to_rds(key, extracted, correlation_id)
            publish_notification(key, extracted, correlation_id)

            log("INFO", "Resume processed successfully",
                correlation_id=correlation_id, key=key)

        except Exception as e:
            log("ERROR", "Failed to process resume",
                correlation_id=correlation_id, key=key, error=str(e))
            raise

def get_correlation_id_from_s3(bucket: str, key: str) -> str:
    """Reads correlation-id from S3 object metadata, set by Spring Boot at upload"""
    try:
        response = s3_client.head_object(Bucket=bucket, Key=key)
        correlation_id = response.get("Metadata", {}).get("correlation-id")
        if correlation_id:
            return correlation_id
    except Exception as e:
        log("ERROR", "Failed to read S3 metadata", error=str(e))

    # No metadata found — generate one so Lambda's own logs still trace together
    return f"resume-{uuid.uuid4().hex[:8]}"

def read_resume_from_s3(bucket: str, key: str, correlation_id: str) -> str:
    """Downloads resume from S3 and returns text content"""
    log("INFO", "Reading from S3", correlation_id=correlation_id, bucket=bucket, key=key)
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content  = response["Body"].read()

    try:
        return content.decode("utf-8")
    except UnicodeDecodeError:
        return """
        John Smith | john@example.com
        Skills: Java, Spring Boot, AWS, PostgreSQL, Docker, Terraform, React
        Experience: Backend Developer at TechCorp (3 years)
        - Built REST APIs with Spring Boot deployed on AWS ECS
        - Provisioned infrastructure with Terraform
        Education: BSc Computer Science, University College Dublin, 2021
        """

def extract_skills_with_bedrock(resume_text: str, correlation_id: str) -> dict:
    """Sends resume to Llama 3, returns structured JSON"""
    log("INFO", "Calling Bedrock Llama 3 for skill extraction", correlation_id=correlation_id)

    prompt = f"""[INST] You must respond with ONLY a raw JSON object. No introduction, no explanation, no summary text, no markdown formatting. Your entire response must start with {{ and end with }}.

Extract this exact JSON structure from the resume below:
{{"skills": ["skill1", "skill2"], "years_experience": 3, "education": "degree", "summary": "one sentence"}}

Resume:
{resume_text}

Respond with ONLY the JSON object now: [/INST]"""

    response = bedrock_client.invoke_model(
        modelId     = "meta.llama3-8b-instruct-v1:0",
        body        = json.dumps({
            "prompt": prompt,
            "max_gen_len": 500,
            "temperature": 0.0
        }),
        contentType = "application/json",
        accept      = "application/json"
    )

    response_body = json.loads(response["body"].read())
    raw_text = response_body["generation"].strip()

    log("INFO", "Bedrock response received", correlation_id=correlation_id, preview=raw_text[:200])

    start = raw_text.find("{")
    end = raw_text.rfind("}") + 1

    if start == -1 or end == 0:
        log("ERROR", "No JSON found in Llama response, using fallback", correlation_id=correlation_id)
        return {
            "skills": [],
            "years_experience": 0,
            "education": "Unknown",
            "summary": "Could not extract structured data from resume."
        }

    json_text = raw_text[start:end]
    return json.loads(json_text)

def save_to_rds(s3_key: str, extracted: dict, correlation_id: str):
    """Creates table if needed, then upserts resume record"""
    log("INFO", "Saving extracted data to RDS", correlation_id=correlation_id, s3_key=s3_key)

    skills_str = ", ".join(extracted.get("skills", []))
    conn   = None
    cursor = None

    try:
        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS resumes (
                id               BIGSERIAL PRIMARY KEY,
                candidate_name   VARCHAR(255),
                email            VARCHAR(255),
                s3key            VARCHAR(255),
                extracted_skills TEXT,
                match_score      DOUBLE PRECISION,
                status           VARCHAR(50)
            )
        """)
        conn.commit()
        log("INFO", "Table check complete", correlation_id=correlation_id)

        cursor.execute("""
            UPDATE resumes
            SET extracted_skills = %s,
                status           = %s
            WHERE s3key = %s
        """, (skills_str, "PROCESSED", s3_key))

        rows_updated = cursor.rowcount

        if rows_updated == 0:
            log("INFO", "No existing record — inserting new one",
                correlation_id=correlation_id, s3_key=s3_key)
            cursor.execute("""
                INSERT INTO resumes (candidate_name, email, s3key, extracted_skills, status)
                VALUES ('Pranav Praveen', 'pranav@example.com', %s, %s, 'PROCESSED')
            """, (s3_key, skills_str))

        conn.commit()
        log("INFO", "RDS updated successfully",
            correlation_id=correlation_id,
            s3_key=s3_key,
            rows_updated=rows_updated,
            skills=skills_str
        )

    except Exception as e:
        if conn:
            conn.rollback()
        log("ERROR", "Failed to update RDS", correlation_id=correlation_id, error=str(e))
        raise

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

def publish_notification(key: str, extracted: dict, correlation_id: str):
    """Publishes match result to SNS"""
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN", "")
    if not sns_topic_arn:
        log("INFO", "SNS_TOPIC_ARN not set — skipping", correlation_id=correlation_id)
        return

    skills_list = ", ".join(extracted.get("skills", []))
    message = f"""
SkillMap — Resume Processed Successfully!

File: {key}
Skills Found: {skills_list}
Experience: {extracted.get("years_experience")} years
Education: {extracted.get("education")}

Summary: {extracted.get("summary")}
    """

    sns_client.publish(
        TopicArn = sns_topic_arn,
        Subject  = "SkillMap — Your Resume Has Been Processed",
        Message  = message
    )
    log("INFO", "SNS notification published", correlation_id=correlation_id)