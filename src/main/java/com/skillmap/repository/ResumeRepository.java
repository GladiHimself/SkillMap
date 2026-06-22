package com.skillmap.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.skillmap.model.Resume;
import com.skillmap.model.ResumeStatus;

public interface ResumeRepository extends JpaRepository<Resume, Long> {
    // Custom query — find all resumes with a given status
    List<Resume> findByStatus(ResumeStatus status);

}
