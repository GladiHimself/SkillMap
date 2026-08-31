package com.skillmap.service;

import com.skillmap.dto.MatchResultDTO;
import com.skillmap.model.Job;
import com.skillmap.model.Resume;
import com.skillmap.repository.JobRepository;
import com.skillmap.repository.ResumeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import static net.logstash.logback.argument.StructuredArguments.kv;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MatchService {

    private final ResumeRepository resumeRepository;
    private final JobRepository jobRepository;
    private final NotificationService notificationService;

    public MatchResultDTO matchResumeToJob(Long resumeId, Long jobId) {
        Resume resume = resumeRepository.findById(resumeId)
                .orElseThrow(() -> new RuntimeException("Resume not found: " + resumeId));

        Job job = jobRepository.findById(jobId)
                .orElseThrow(() -> new RuntimeException("Job not found: " + jobId));

        MatchResultDTO result = calculateMatch(resume, job);

        // Send notification after calculating match ← NEW
        notificationService.sendMatchNotification(result);

        return result;
    }

    public MatchResultDTO calculateMatch(Resume resume, Job job) {
        List<String> resumeSkills = parseSkills(resume.getExtractedSkills());
        List<String> jobSkills    = parseSkills(job.getRequiredSkills());

        List<String> matchedSkills = resumeSkills.stream()
                .filter(skill -> jobSkills.stream()
                        .anyMatch(jobSkill -> jobSkill.equalsIgnoreCase(skill)))
                .collect(Collectors.toList());

        List<String> missingSkills = jobSkills.stream()
                .filter(skill -> resumeSkills.stream()
                        .noneMatch(resumeSkill -> resumeSkill.equalsIgnoreCase(skill)))
                .collect(Collectors.toList());

        double score = jobSkills.isEmpty() ? 0.0 :
                ((double) matchedSkills.size() / jobSkills.size()) * 100;
        score = Math.round(score * 10.0) / 10.0;

        String verdict = getVerdict(score);

        resume.setMatchScore(score);
        resumeRepository.save(resume);

        log.info("Match calculated",
        kv("candidate", resume.getCandidateName()),
        kv("matchScore", score),
        kv("jobTitle", job.getTitle()),
        kv("company", job.getCompany()));

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