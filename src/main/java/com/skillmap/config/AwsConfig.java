package com.skillmap.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.sns.SnsClient;

@Configuration
public class AwsConfig {

    @Bean
    public BedrockRuntimeClient bedrockRuntimeClient() {
        return BedrockRuntimeClient.builder()
                .region(Region.AP_SOUTH_1)
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    // NEW — SNS client bean
    // Spring Boot uses this to publish match score notifications
    @Bean
    public SnsClient snsClient() {
        return SnsClient.builder()
                .region(Region.AP_SOUTH_1)
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    @Bean
    public S3Presigner s3Presigner() {
        return S3Presigner.builder()
                .region(Region.AP_SOUTH_1)
                .build();
    }

}