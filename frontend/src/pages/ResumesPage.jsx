import { useState, useEffect } from 'react';
import { getAllResumes, createResume, getUploadUrl, uploadFileToS3 } from '../api';

// Badge colour based on resume status
const statusBadge = {
  UPLOADED: 'badge-yellow',
  PROCESSED: 'badge-blue',
  MATCHED: 'badge-green',
  FAILED: 'badge-red'
};

export default function ResumesPage() {
  const [resumes, setResumes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState({});
  const [success, setSuccess] = useState('');
  const [uploading, setUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);

  const [form, setForm] = useState({ candidateName: '', email: '' });

  useEffect(() => {
    fetchResumes();
  }, []);

  const fetchResumes = async () => {
    try {
      const data = await getAllResumes();
      setResumes(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    setErrors({});
    setSuccess('');

    if (!selectedFile) {
      setErrors({ file: 'Please choose a PDF file to upload' });
      return;
    }

    setUploading(true);

    try {
      // Step 1 — get a pre-signed URL from the backend
      // This also generates the correlation ID used for tracing
      const { uploadUrl, s3Key, correlationId } = await getUploadUrl(selectedFile.name);

      // Step 2 — register the candidate record FIRST
      // The row must exist before Lambda fires, otherwise Lambda
      // can't find it and inserts a duplicate instead of updating
      const newResume = await createResume({ ...form, s3Key });

      // Step 3 — upload the file, which triggers the Lambda pipeline
      // The file never passes through our Spring Boot server
      await uploadFileToS3(uploadUrl, selectedFile, correlationId);

      setResumes([...resumes, newResume]);
      setForm({ candidateName: '', email: '' });
      setSelectedFile(null);
      setSuccess('Resume uploaded! AI is processing it — refresh in a few seconds.');

    } catch (err) {
      console.error(err);
      setErrors(typeof err === 'object' ? err : { file: 'Upload failed' });
    } finally {
      setUploading(false);
    }
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleFileChange = (e) => {
    setSelectedFile(e.target.files[0]);
    setErrors({});
  };

  return (
    <div className="container">
      <h2 style={{ margin: '1.5rem 0 1rem' }}>Resumes</h2>

      {/* Upload Resume Form */}
      <div className="card">
        <h3 style={{ marginBottom: '0.5rem' }}>Upload a Resume</h3>
        <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '1rem' }}>
          Upload a PDF — AI will extract skills automatically.
        </p>

        <div className="form-group">
          <label>Candidate Name</label>
          <input
            name="candidateName"
            value={form.candidateName}
            onChange={handleChange}
            placeholder="e.g. Pranav Praveen"
          />
          {errors.candidateName && <div className="error">{errors.candidateName}</div>}
        </div>

        <div className="form-group">
          <label>Email</label>
          <input
            name="email"
            value={form.email}
            onChange={handleChange}
            placeholder="e.g. pranav@example.com"
          />
          {errors.email && <div className="error">{errors.email}</div>}
        </div>

        <div className="form-group">
          <label>Resume (PDF)</label>
          <input
            type="file"
            accept=".pdf"
            onChange={handleFileChange}
          />
          {selectedFile && (
            <small style={{ color: '#64748b' }}>
              Selected: {selectedFile.name} ({Math.round(selectedFile.size / 1024)} KB)
            </small>
          )}
          {errors.file && <div className="error">{errors.file}</div>}
        </div>

        {success && <div className="success">{success}</div>}

        <button
          className="btn btn-primary"
          onClick={handleSubmit}
          disabled={uploading}
        >
          {uploading ? 'Uploading...' : 'Upload Resume'}
        </button>
      </div>

      {/* Refresh button — Lambda processes asynchronously */}
      <button
        className="btn"
        onClick={fetchResumes}
        style={{ marginBottom: '1rem', background: '#e2e8f0' }}
      >
        ↻ Refresh Status
      </button>

      {/* Resumes List */}
      {loading ? (
        <p>Loading resumes...</p>
      ) : resumes.length === 0 ? (
        <p>No resumes yet.</p>
      ) : (
        resumes.map(resume => (
          <div className="card" key={resume.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div>
                <h3>{resume.candidateName}</h3>
                <p style={{ color: '#64748b', fontSize: '0.9rem' }}>{resume.email}</p>
                {resume.extractedSkills && (
                  <div style={{ marginTop: '0.5rem' }}>
                    {resume.extractedSkills.split(',').map(skill => (
                      <span key={skill} className="badge badge-blue"
                        style={{ marginRight: '0.3rem', marginBottom: '0.3rem', display: 'inline-block' }}>
                        {skill.trim()}
                      </span>
                    ))}
                  </div>
                )}
                {resume.matchScore !== null && (
                  <p style={{ fontSize: '0.9rem', marginTop: '0.3rem' }}>
                    Match Score: <strong>{resume.matchScore}%</strong>
                  </p>
                )}
              </div>
              <span className={`badge ${statusBadge[resume.status]}`}>
                {resume.status}
              </span>
            </div>
          </div>
        ))
      )}
    </div>
  );
}