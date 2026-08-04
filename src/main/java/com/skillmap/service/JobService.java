package com.skillmap.service;

import com.skillmap.dto.JobRequestDTO;
import com.skillmap.dto.JobResponseDTO;
import com.skillmap.model.Job;
import com.skillmap.repository.JobRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;


import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;


@Slf4j
@Service
@RequiredArgsConstructor
public class JobService {

    private final JobRepository jobRepository;

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

        // If no skills provided but description exists → use AI to extract
        if ((requiredSkills == null || requiredSkills.isBlank())
                && request.getDescription() != null
                && !request.getDescription().isBlank()) {

            log.info("Extracting skills from job description using Bedrock");
            requiredSkills = extractSkillsFromDescription(request.getDescription());
            log.info("Extracted skills: {}", requiredSkills);
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
    log.info("Extracting skills from description (keyword scan)");

    // Known technical skills to look for
    // Stand-in for Bedrock until AWS payment method is sorted
    String[] knownSkills = {
        "Java", "Spring Boot", "Spring", "AWS", "Docker", "Kubernetes",
        "PostgreSQL", "MySQL", "MongoDB", "Redis", "React", "Angular",
        "Vue", "TypeScript", "JavaScript", "Python", "Node.js", "Go",
        "Terraform", "Jenkins", "Kafka", "GraphQL", "REST", "Microservices",
        "CI/CD", "Git", "Linux", "Azure", "GCP", "Lambda", "S3"
    };

    List<String> found = new ArrayList<>();
    String lowerDesc = description.toLowerCase();

    for (String skill : knownSkills) {
        if (lowerDesc.contains(skill.toLowerCase())) {
            found.add(skill);
        }
    }

    String result = String.join(", ", found);
    log.info("Found skills: {}", result);
    return result;
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