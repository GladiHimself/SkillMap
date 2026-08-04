package com.skillmap.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data
@Builder
public class MatchResultDTO {

    private Long resumeId;
    private Long jobId;
    private String candidateName;
    private String jobTitle;
    private String company;

    // Skills the candidate has that match the job
    private List<String> matchedSkills;

    // Skills the job needs that candidate doesn't have
    private List<String> missingSkills;

    // Percentage match — e.g. 75.0
    private Double matchScore;

    // Human readable verdict
    private String verdict;
}
