package com.skillmap.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.skillmap.model.Job;
import com.skillmap.repository.JobRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class JobService {

    private final JobRepository jobRepository;

    public List<Job> getAllJobs() {
        return jobRepository.findAll();
    }

    public Job getJobById(Long id) {
        return jobRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Job not found" + id));
    }

    public Job createJob(Job job) {
        return jobRepository.save(job);
    }

    public void deleteJob(Long id) {
        jobRepository.deleteById(id);
    }

}
