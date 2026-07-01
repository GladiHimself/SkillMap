import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Navbar from './components/Navbar';
import JobsPage from './pages/JobsPage';
import ResumesPage from './pages/ResumesPage';

export default function App() {
  return (
    <BrowserRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<Navigate to="/jobs" replace />} />
        <Route path="/jobs" element={<JobsPage />} />
        <Route path="/resumes" element={<ResumesPage />} />
      </Routes>
    </BrowserRouter>
  );
}