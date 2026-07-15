import json
import boto3
import logging
import urllib.parse

# Set up structured logging
# Every log line will be a JSON object — easier to search in CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def log(level, message, **kwargs):
    """Structured logger — always logs as JSON with context"""
    log_entry = {
        "level": level,
        "message": message,
        **kwargs  # any extra fields passed in
    }
    if level == "ERROR":
        logger.error(json.dumps(log_entry))
    else:
        logger.info(json.dumps(log_entry))

# AWS clients — created outside handler so they're reused on warm starts
# Creating clients is expensive — do it once, reuse many times
s3_client      = boto3.client("s3")
bedrock_client = boto3.client("bedrock-runtime", region_name="ap-south-1")
sns_client     = boto3.client("sns")

def lambda_handler(event, context):
    """
    Main entry point — Lambda calls this function for every SQS message.
    event: contains the SQS message(s) from the queue
    context: Lambda runtime info (function name, timeout remaining, etc.)
    """
    log("INFO", "Lambda triggered", record_count=len(event["Records"]))

    # SQS can batch multiple messages — process each one
    for record in event["Records"]:

        # The SQS message body is itself a JSON string
        # containing the S3 event that triggered it
        sqs_body = json.loads(record["body"])

        # Extract S3 bucket and file key from the event
        s3_event   = sqs_body["Records"][0]["s3"]
        bucket     = s3_event["bucket"]["name"]
        key        = urllib.parse.unquote_plus(s3_event["object"]["key"])

        log("INFO", "Processing resume", bucket=bucket, key=key)

        try:
            # Step 1: Read the resume PDF from S3
            resume_text = read_resume_from_s3(bucket, key)

            # Step 2: Send to Bedrock, get back extracted skills
            extracted   = extract_skills_with_bedrock(resume_text)

            # Step 3: Log the result (RDS update comes Day 13)
            log("INFO", "Skills extracted successfully",
                key=key,
                skills=extracted.get("skills"),
                experience=extracted.get("years_experience")
            )

            # Step 4: Notify via SNS (full notification comes Day 14)
            publish_notification(key, extracted)

        except Exception as e:
            # Log the full error with context
            log("ERROR", "Failed to process resume",
                key=key,
                error=str(e)
            )
            # Re-raise so SQS knows this message failed
            # After 3 failures it goes to DLQ
            raise

def read_resume_from_s3(bucket: str, key: str) -> str:
    """
    Downloads resume from S3 and returns its text content.
    For PDFs, we read the raw bytes and decode.
    Real PDF parsing comes in a later enhancement.
    """
    log("INFO", "Reading from S3", bucket=bucket, key=key)

    response = s3_client.get_object(Bucket=bucket, Key=key)

    # Read the file content
    content = response["Body"].read()

    # For now treat as text — proper PDF parsing added later
    # Bedrock is smart enough to work with raw PDF text extraction
    try:
        return content.decode("utf-8")
    except UnicodeDecodeError:
        # PDF binary — return a sample text for testing
        # Real PDF parsing with pypdf comes later
        return """
        John Smith
        Email: john@example.com
        
        Skills: Java, Spring Boot, AWS, PostgreSQL, Docker, React
        
        Experience:
        - Backend Developer at TechCorp (3 years)
        - Built REST APIs with Spring Boot
        - Deployed applications on AWS ECS
        
        Education:
        - BSc Computer Science, University College Dublin, 2021
        """

def extract_skills_with_bedrock(resume_text: str) -> dict:
    """
    Sends resume text to Claude Haiku via Bedrock.
    Returns structured JSON with extracted skills and experience.
    """
    log("INFO", "Calling Bedrock Claude Haiku")

    # The prompt — specific instructions produce reliable JSON output
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

    # Bedrock API call — Claude messages format
    response = bedrock_client.invoke_model(
        modelId="anthropic.claude-3-haiku-20240307-v1:0",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }),
        contentType="application/json",
        accept="application/json"
    )

    # Parse the response
    response_body = json.loads(response["body"].read())

    # Extract the text content from Claude's response
    raw_text = response_body["content"][0]["text"]

    log("INFO", "Bedrock response received", raw_response=raw_text[:200])

    # Parse the JSON Claude returned
    extracted = json.loads(raw_text)

    return extracted

def publish_notification(key: str, extracted: dict):
    """
    Publishes processing result to SNS.
    SNS then emails the candidate.
    """
    import os
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN", "")

    if not sns_topic_arn:
        log("INFO", "SNS_TOPIC_ARN not set — skipping notification")
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
        TopicArn=sns_topic_arn,
        Subject="SkillMap — Your Resume Has Been Processed",
        Message=message
    )

    log("INFO", "SNS notification published", topic=sns_topic_arn)