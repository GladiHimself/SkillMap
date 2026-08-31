package com.skillmap.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.skillmap.dto.JobRequestDTO;
import com.skillmap.dto.JobResponseDTO;
import com.skillmap.model.Job;
import com.skillmap.repository.JobRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelResponse;

import java.util.List;
import java.util.Map;

import static net.logstash.logback.argument.StructuredArguments.kv;

@Slf4j
@Service
@RequiredArgsConstructor
public class JobService {

    private final JobRepository jobRepository;
    private final BedrockRuntimeClient bedrockClient;
    private final ObjectMapper objectMapper;

    public List<JobResponseDTO> getAllJobs() {
        return jobRepository.findAll()
                .stream()
                .map(this::toResponseDTO)
                .toList();
    }

    public JobResponseDTO getJobById(Long id) {
        Job job = jobRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Job not found: " + id));
        return toResponseDTO(job);
    }

    public JobResponseDTO createJob(JobRequestDTO request) {

        String requiredSkills = request.getRequiredSkills();

        if ((requiredSkills == null || requiredSkills.isBlank())
                && request.getDescription() != null
                && !request.getDescription().isBlank()) {

            log.info("Extracting skills from job description using Bedrock",
                    kv("jobTitle", request.getTitle()),
                    kv("company", request.getCompany()));

            requiredSkills = extractSkillsFromDescription(request.getDescription());

            log.info("Skills extracted from description",
                    kv("jobTitle", request.getTitle()),
                    kv("extractedSkills", requiredSkills));
        }

        Job job = Job.builder()
                .title(request.getTitle())
                .company(request.getCompany())
                .description(request.getDescription())
                .requiredSkills(requiredSkills)
                .build();

        return toResponseDTO(jobRepository.save(job));
    }

    public void deleteJob(Long id) {
        jobRepository.deleteById(id);
    }

    public String extractSkillsFromDescription(String description) {
        log.info("Calling Bedrock Llama 3 for skill extraction");

        String prompt = """
                You are an expert technical recruiter.
                Extract ONLY the technical skills from this job description.
                Return ONLY a comma-separated list of skills.
                No explanation, no numbering, no bullets — just the skills.
                
                Example output: Java, Spring Boot, AWS, PostgreSQL, Docker
                
                Job Description:
                """ + description;

        try {
            String requestBody = objectMapper.writeValueAsString(Map.of(
                    "prompt", prompt,
                    "max_gen_len", 500,
                    "temperature", 0.1
            ));

            InvokeModelResponse response = bedrockClient.invokeModel(
                    InvokeModelRequest.builder()
                            .modelId("meta.llama3-8b-instruct-v1:0")
                            .body(SdkBytes.fromUtf8String(requestBody))
                            .contentType("application/json")
                            .accept("application/json")
                            .build()
            );

            Map<?, ?> responseMap = objectMapper.readValue(
                    response.body().asUtf8String(), Map.class);
            String skills = responseMap.get("generation").toString().trim();

            log.info("Bedrock Llama 3 response received",
                    kv("modelId", "meta.llama3-8b-instruct-v1:0"),
                    kv("skills", skills));

            return skills;

        } catch (Exception e) {
            log.error("Failed to extract skills from description",
                    kv("errorMessage", e.getMessage()));
            return "";
        }
    }

    private JobResponseDTO toResponseDTO(Job job) {
        return JobResponseDTO.builder()
                .id(job.getId())
                .title(job.getTitle())
                .company(job.getCompany())
                .description(job.getDescription())
                .requiredSkills(job.getRequiredSkills())
                .build();
    }
}