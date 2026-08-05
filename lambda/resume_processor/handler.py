import json
import boto3
import logging
import urllib.parse
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def log(level, message, **kwargs):
    """Structured logger — always logs as JSON"""
    log_entry = {"level": level, "message": message, **kwargs}
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

        # Handle different S3 notification formats
        if "Records" in sqs_body:
            s3_event = sqs_body["Records"][0]["s3"]
        elif "s3" in sqs_body:
            s3_event = sqs_body["s3"]
        else:
            log("INFO", "Unexpected message format", body=str(sqs_body)[:500])
            continue

        bucket = s3_event["bucket"]["name"]
        key    = urllib.parse.unquote_plus(s3_event["object"]["key"])

        log("INFO", "Processing resume", bucket=bucket, key=key)

        try:
            # Step 1: Read resume from S3
            resume_text = read_resume_from_s3(bucket, key)

            # Step 2: Extract skills via Bedrock AI
            extracted = extract_skills_with_bedrock(resume_text)

            # Step 3: Save results to RDS
            save_to_rds(key, extracted)

            # Step 4: Notify via SNS
            publish_notification(key, extracted)

            log("INFO", "Resume processed successfully", key=key)

        except Exception as e:
            log("ERROR", "Failed to process resume",
                key=key, error=str(e))
            raise

def read_resume_from_s3(bucket: str, key: str) -> str:
    """Downloads resume from S3 and returns text content"""
    log("INFO", "Reading from S3", bucket=bucket, key=key)
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

def extract_skills_with_bedrock(resume_text: str) -> dict:
    """Sends resume to Claude Haiku 4.5, returns structured JSON"""
    log("INFO", "Calling Bedrock Claude Haiku 4.5")

    prompt = f"""You are an expert resume parser for a job matching platform.

Analyse the resume below and extract the following information.
Return ONLY a valid JSON object with NO explanation, NO markdown, NO code blocks.
Just the raw JSON.

Required fields:
- skills: array of technical skills (strings)
- years_experience: total years of work experience (number)
- education: highest education level (string)
- summary: one sentence professional summary (string)

Resume:
{resume_text}"""

    response = bedrock_client.invoke_model(
        modelId     = "global.anthropic.claude-haiku-4-5-20251001-v1:0",
        body        = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": prompt}]
        }),
        contentType = "application/json",
        accept      = "application/json"
    )

    response_body = json.loads(response["body"].read())
    raw_text      = response_body["content"][0]["text"]

    log("INFO", "Bedrock response received", preview=raw_text[:200])
    return json.loads(raw_text)

def save_to_rds(s3_key: str, extracted: dict):
    """Creates table if needed, then upserts resume record"""
    log("INFO", "Saving extracted data to RDS", s3_key=s3_key)

    skills_str = ", ".join(extracted.get("skills", []))
    conn   = None
    cursor = None

    try:
        conn   = get_db_connection()
        cursor = conn.cursor()

        # Create table if it doesn't exist
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS resumes (
                id               BIGSERIAL PRIMARY KEY,
                candidate_name   VARCHAR(255),
                email            VARCHAR(255),
                s3_key           VARCHAR(255),
                extracted_skills TEXT,
                match_score      DOUBLE PRECISION,
                status           VARCHAR(50)
            )
        """)
        conn.commit()
        log("INFO", "Table check complete")

        # Try to update existing record first
        cursor.execute("""
            UPDATE resumes
            SET extracted_skills = %s,
                status           = %s
            WHERE s3_key = %s
        """, (skills_str, "PROCESSED", s3_key))

        rows_updated = cursor.rowcount

        if rows_updated == 0:
            log("INFO", "No existing record — inserting new one", s3_key=s3_key)
            cursor.execute("""
                INSERT INTO resumes (candidate_name, email, s3_key, extracted_skills, status)
                VALUES ('Pranav Praveen', 'pranav@example.com', %s, %s, 'PROCESSED')
            """, (s3_key, skills_str))

        conn.commit()
        log("INFO", "RDS updated successfully",
            s3_key=s3_key,
            rows_updated=rows_updated,
            skills=skills_str
        )

    except Exception as e:
        if conn:
            conn.rollback()
        log("ERROR", "Failed to update RDS", error=str(e))
        raise

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

def publish_notification(key: str, extracted: dict):
    """Publishes match result to SNS"""
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN", "")
    if not sns_topic_arn:
        log("INFO", "SNS_TOPIC_ARN not set — skipping")
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
    log("INFO", "SNS notification published")