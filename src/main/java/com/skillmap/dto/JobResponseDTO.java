package com.skillmap.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class JobResponseDTO {

    private Long id;
    private String title;
    private String company;
    private String requiredSkills;
    private String description;

}
