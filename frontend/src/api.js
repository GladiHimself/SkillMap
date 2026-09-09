// Central place for all API calls
// If backend URL changes, we only change it here
// Reads from .env.production when built, falls back to proxy locally
const BASE_URL = import.meta.env.VITE_API_URL
  ? `${import.meta.env.VITE_API_URL}/api/v1`
  : '/api/v1';

// ── Jobs ──────────────────────────────────────
export const getAllJobs = async () => {
  const res = await fetch(`${BASE_URL}/jobs`);
  if (!res.ok) throw new Error('Failed to fetch jobs');
  return res.json();
};

export const createJob = async (jobData) => {
  const res = await fetch(`${BASE_URL}/jobs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(jobData)
  });
  if (!res.ok) {
    const error = await res.json();
    throw error;  // validation errors from GlobalExceptionHandler
  }
  return res.json();
};

// ── Resumes ───────────────────────────────────
export const getAllResumes = async () => {
  const res = await fetch(`${BASE_URL}/resumes`);
  if (!res.ok) throw new Error('Failed to fetch resumes');
  return res.json();
};

export const createResume = async (resumeData) => {
  const res = await fetch(`${BASE_URL}/resumes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(resumeData)
  });
  if (!res.ok) {
    const error = await res.json();
    throw error;
  }
  return res.json();
};

export const matchResumeToJob = async (resumeId, jobId) => {
  const res = await fetch(
    `${BASE_URL}/match?resumeId=${resumeId}&jobId=${jobId}`,
    { method: 'POST' }
  );
  if (!res.ok) throw new Error('Match failed');
  return res.json();
};

// Get a pre-signed S3 upload URL from the backend
export const getUploadUrl = async (fileName) => {
  const res = await fetch(`${BASE_URL}/resumes/upload-url?fileName=${encodeURIComponent(fileName)}`);
  if (!res.ok) throw new Error('Failed to get upload URL');

  // Correlation ID comes back in the response header
  const correlationId = res.headers.get('X-Correlation-Id');
  const data = await res.json();
  return { ...data, correlationId };
};

// Upload the file directly from browser to S3 using the pre-signed URL
// The correlation ID header must match what the URL was signed with
export const uploadFileToS3 = async (uploadUrl, file, correlationId) => {
  const res = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'x-amz-meta-correlation-id': correlationId },
    body: file
  });
  if (!res.ok) throw new Error('S3 upload failed');
  return true;
};