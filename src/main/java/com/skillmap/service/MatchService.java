package com.skillmap.service;

import com.skillmap.dto.MatchResultDTO;
import com.skillmap.model.Job;
import com.skillmap.model.Resume;
import com.skillmap.repository.JobRepository;
import com.skillmap.repository.ResumeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MatchService {

    private final ResumeRepository resumeRepository;
    private final JobRepository jobRepository;

    public MatchResultDTO matchResumeToJob(Long resumeId, Long jobId) {

        Resume resume = resumeRepository.findById(resumeId)
                .orElseThrow(() -> new RuntimeException("Resume not found: " + resumeId));

        Job job = jobRepository.findById(jobId)
                .orElseThrow(() -> new RuntimeException("Job not found: " + jobId));

        return calculateMatch(resume, job);
    }

    public MatchResultDTO calculateMatch(Resume resume, Job job) {

        // Parse skills from comma-separated strings
        // toLowerCase ensures "Java" matches "java"
        List<String> resumeSkills = parseSkills(resume.getExtractedSkills());
        List<String> jobSkills    = parseSkills(job.getRequiredSkills());

        // Find skills that appear in both lists
        List<String> matchedSkills = resumeSkills.stream()
                .filter(skill -> jobSkills.stream()
                        .anyMatch(jobSkill -> jobSkill.equalsIgnoreCase(skill)))
                .collect(Collectors.toList());

        // Find skills job needs that candidate doesn't have
        List<String> missingSkills = jobSkills.stream()
                .filter(skill -> resumeSkills.stream()
                        .noneMatch(resumeSkill -> resumeSkill.equalsIgnoreCase(skill)))
                .collect(Collectors.toList());

        // Calculate percentage score
        double score = jobSkills.isEmpty() ? 0.0 :
                ((double) matchedSkills.size() / jobSkills.size()) * 100;

        // Round to 1 decimal place
        score = Math.round(score * 10.0) / 10.0;

        // Human readable verdict based on score
        String verdict = getVerdict(score);

        // Save match score back to resume
        resume.setMatchScore(score);
        resumeRepository.save(resume);

        return MatchResultDTO.builder()
                .resumeId(resume.getId())
                .jobId(job.getId())
                .candidateName(resume.getCandidateName())
                .jobTitle(job.getTitle())
                .company(job.getCompany())
                .matchedSkills(matchedSkills)
                .missingSkills(missingSkills)
                .matchScore(score)
                .verdict(verdict)
                .build();
    }

    private List<String> parseSkills(String skillsString) {
        if (skillsString == null || skillsString.isBlank()) {
            return List.of();
        }
        // Split by comma, trim whitespace, filter empty strings
        return Arrays.stream(skillsString.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }

    private String getVerdict(double score) {
        if (score >= 80) return "Excellent match — strongly recommend";
        if (score >= 60) return "Good match — worth interviewing";
        if (score >= 40) return "Partial match — consider with reservations";
        return "Poor match — significant skill gaps";
    }
}