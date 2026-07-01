import { NavLink } from 'react-router-dom';

export default function Navbar() {
  return (
    <nav>
      <span className="logo">⚡ SkillMap</span>
      <NavLink
        to="/jobs"
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Jobs
      </NavLink>
      <NavLink
        to="/resumes"
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Resumes
      </NavLink>
    </nav>
  );
}