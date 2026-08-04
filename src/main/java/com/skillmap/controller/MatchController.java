package com.skillmap.controller;


import com.skillmap.dto.MatchResultDTO;
import com.skillmap.service.MatchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/match")
@RequiredArgsConstructor
public class MatchController {

    private final MatchService matchService;

    // Match a specific resume against a specific job
    @PostMapping
    public ResponseEntity<MatchResultDTO> match(
            @RequestParam Long resumeId,
            @RequestParam Long jobId) {
        return ResponseEntity.ok(matchService.matchResumeToJob(resumeId, jobId));
    }
}