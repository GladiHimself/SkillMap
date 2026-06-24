package com.skillmap.service;


import com.skillmap.dto.ResumeRequestDTO;
import com.skillmap.dto.ResumeResponseDTO;
import com.skillmap.model.Resume;
import com.skillmap.model.ResumeStatus;
import com.skillmap.repository.ResumeRepository;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.RequestBody;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ResumeService {

    private final ResumeRepository resumeRepository;

    public List<ResumeResponseDTO> getAllResumes() {
        return resumeRepository.findAll()
                .stream()
                .map(this::toResponseDTO)
                .toList();
    }

    public ResumeResponseDTO getResumeById(Long id) {
        Resume resume = resumeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Resume not found: " + id));
        return toResponseDTO(resume);
    }

    public ResumeResponseDTO createResume(ResumeRequestDTO request) {
        Resume resume = Resume.builder()
                .candidateName(request.getCandidateName())
                .email(request.getEmail())
                .status(ResumeStatus.UPLOADED)
                .build();

        Resume saved = resumeRepository.save(resume);
        return toResponseDTO(saved);
    }

    // Private mapper — entity → response DTO
    private ResumeResponseDTO toResponseDTO(Resume resume) {
        return ResumeResponseDTO.builder()
                .id(resume.getId())
                .candidateName(resume.getCandidateName())
                .email(resume.getEmail())
                .extractedSkills(resume.getExtractedSkills())
                .matchScore(resume.getMatchScore())
                .status(resume.getStatus())
                .build();
    }
}