package com.skillmap.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.skillmap.model.Resume;
import com.skillmap.model.ResumeStatus;
import com.skillmap.repository.ResumeRepository;

import lombok.RequiredArgsConstructor;


@Service
@RequiredArgsConstructor
public class ResumeService {

    private final ResumeRepository resumeRepository;

    public List<Resume> getAllResumes() {
        return resumeRepository.findAll();
    }

    public Resume getResumeById(Long id) {
        return resumeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Resume not found" + id));
    }

    public Resume createResume(Resume resume) {
        resume.setStatus(ResumeStatus.UPLOADED);
        return resumeRepository.save(resume);
    }
    
}
