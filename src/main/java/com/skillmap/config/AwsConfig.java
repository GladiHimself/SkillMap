package com.skillmap.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;

@Configuration
public class AwsConfig {

    // Creates the Bedrock client as a Spring bean
    // so JobService can inject it via constructor
    @Bean
    public BedrockRuntimeClient bedrockRuntimeClient() {
        // Uses default credential chain — picks up your aws configure
        // credentials locally, and the ECS task role in production
        return BedrockRuntimeClient.builder()
                .region(Region.AP_SOUTH_1)
                .build();
    }
}