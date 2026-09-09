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
                                <|begin_of_text|><|start_header_id|>system<|end_header_id|>

                                You are a skill extraction tool. Output ONLY a comma-separated list of technical skills found in the text. No sentences, no explanations, no extra skills not mentioned in the text.<|eot_id|><|start_header_id|>user<|end_header_id|>

                                Extract the technical skills from this job description:

                                """
                                + description + """
                                                <|eot_id|><|start_header_id|>assistant<|end_header_id|>

                                                """;

                try {
                        String requestBody = objectMapper.writeValueAsString(Map.of(
                                        "prompt", prompt,
                                        "max_gen_len", 100,
                                        "temperature", 0.0));

                        InvokeModelResponse response = bedrockClient.invokeModel(
                                        InvokeModelRequest.builder()
                                                        .modelId("meta.llama3-8b-instruct-v1:0")
                                                        .body(SdkBytes.fromUtf8String(requestBody))
                                                        .contentType("application/json")
                                                        .accept("application/json")
                                                        .build());

                        Map<?, ?> responseMap = objectMapper.readValue(
                                        response.body().asUtf8String(), Map.class);
                        String skills = responseMap.get("generation").toString().trim();

                        // Strip Llama special tokens and take only the first line
                        skills = skills
                                        .replaceAll("<\\|.*?\\|>", "") // remove any <|token|> markers
                                        .replaceAll("\\[/?INST\\]", "") // remove stray INST tags
                                        .split("\n")[0]
                                        .replaceAll("[|]+", "")
                                        .trim();
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