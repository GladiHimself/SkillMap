package com.skillmap.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.skillmap.dto.ResumeRequestDTO;
import com.skillmap.dto.ResumeResponseDTO;
import com.skillmap.model.Resume;
import com.skillmap.service.ResumeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;


@RestController
@RequestMapping("/api/v1/resumes")
@RequiredArgsConstructor
public class ResumeController {

    private final ResumeService resumeService;

    @GetMapping
    public List<ResumeResponseDTO> getAllResumes() {
        return resumeService.getAllResumes();
    }

    @GetMapping("/{id}")
    public ResponseEntity<ResumeResponseDTO> getResumeById(@PathVariable Long id) {
        return ResponseEntity.ok(resumeService.getResumeById(id));
    }

    @PostMapping
    public ResponseEntity<ResumeResponseDTO> createResume(@Valid @RequestBody ResumeRequestDTO resumeRequest) {
        return ResponseEntity.ok(resumeService.createResume(resumeRequest));
    }

}
