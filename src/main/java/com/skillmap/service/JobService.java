package com.skillmap.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.skillmap.dto.JobRequestDTO;
import com.skillmap.dto.JobResponseDTO;
import com.skillmap.model.Job;
import com.skillmap.repository.JobRepository;

import lombok.RequiredArgsConstructor;

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
            .orElseThrow(() -> new RuntimeException("Job not found" + id));
        return toResponseDTO(job);
    }

    public JobResponseDTO createJob(JobRequestDTO requestDTO) {
        Job job = Job.builder()
            .title(requestDTO.getTitle())
            .company(requestDTO.getCompany())
            .requiredSkills(requestDTO.getRequiredSkills())
            .description(requestDTO.getDescription())
            .build();

        Job saved = jobRepository.save(job);
        return toResponseDTO(saved);
    }

    public void deleteJob(Long id) {
        jobRepository.deleteById(id);
    }

    private JobResponseDTO toResponseDTO(Job job) {
        return JobResponseDTO.builder()
            .id(job.getId())
            .title(job.getTitle())
            .company(job.getCompany())
            .requiredSkills(job.getRequiredSkills())
            .description(job.getDescription())
            .build();
    }

}
