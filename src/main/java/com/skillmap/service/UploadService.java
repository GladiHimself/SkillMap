package com.skillmap.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;


import java.time.Duration;
import java.util.Map;

import static net.logstash.logback.argument.StructuredArguments.kv;

@Slf4j
@Service
@RequiredArgsConstructor
public class UploadService {

    private final S3Presigner s3Presigner;

    @Value("${aws.s3.bucket.name:skillmap-resumes-dev}")
    private String bucketName;

    // Generates a pre-signed URL the browser can upload directly to
    // The correlation ID is embedded as S3 object metadata so Lambda
    // can pick it up later and continue the same trace
    public String generatePresignedUploadUrl(String s3Key) {

        // Reuse the current request's correlation ID —
        // this ties the upload to everything else in this request
        String correlationId = MDC.get("correlationId");

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(s3Key)
                .metadata(Map.of("correlation-id", correlationId))
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(10))
                .putObjectRequest(putRequest)
                .build();

        PresignedPutObjectRequest presigned = s3Presigner.presignPutObject(presignRequest);

        log.info("Generated pre-signed upload URL",
                kv("s3Key", s3Key),
                kv("correlationId", correlationId));

        return presigned.url().toString();
    }
}