import { useState, useEffect } from 'react';
import { getAllResumes, createResume } from '../api';

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
    try {
      const newResume = await createResume(form);
      setResumes([...resumes, newResume]);
      setForm({ candidateName: '', email: '' });
      setSuccess('Resume registered! Upload feature coming soon.');
    } catch (err) {
      setErrors(err);
    }
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  return (
    <div className="container">
      <h2 style={{ margin: '1.5rem 0 1rem' }}>Resumes</h2>

      {/* Register Resume Form */}
      <div className="card">
        <h3 style={{ marginBottom: '1rem' }}>Register a Resume</h3>
        <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '1rem' }}>
          S3 file upload coming on Day 8. For now, register candidate details.
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

        {success && <div className="success">{success}</div>}

        <button className="btn btn-primary" onClick={handleSubmit}>
          Register Resume
        </button>
      </div>

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
                  <p style={{ fontSize: '0.9rem', marginTop: '0.3rem' }}>
                    Skills: {resume.extractedSkills}
                  </p>
                )}
                {resume.matchScore !== null && (
                  <p style={{ fontSize: '0.9rem' }}>
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