package com.skillmap.dto;

import com.skillmap.model.ResumeStatus;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ResumeResponseDTO {

    private Long id;
    private String candidateName;
    private String email;

    // s3Key intentionally excluded — internal detail, client doesn't need it
    // extractedSkills shown — client wants to see what AI found
    private String extractedSkills;

    private Double matchScore;
    private ResumeStatus status;

}
