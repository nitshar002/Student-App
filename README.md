# Student App

Student Nexus is a student-focused assistant designed to bring academic organization, career preparation, and student wellness tools into one application.

The project was developed as a summer software engineering internship with the goal of exploring how an integrated student platform could simplify some of the tools and resources students use throughout the semester.

## Features

### Academic Organization
- Upload a course syllabus
- Parse syllabus information into structured course data
- Organize courses, assignments, and tasks
- View academic information through a centralized dashboard
- Track upcoming coursework and deadlines

### AI Interview Preparation
- Practice mock interviews
- Receive AI-powered interview questions and interactions
- Simulate an interview-style experience
- Review interview sessions and responses

### Wellness & Mental Health
- Student wellness resources and tools
- Track wellness-related information
- Features designed to encourage healthy habits and self-awareness

### Sleep
- Sleep-related tracking and insights
- Tools designed to help students build healthier sleep habits

### User Accounts
- User authentication through Supabase
- User-specific application data
- Database-backed profiles and student information

## Tech Stack

**Frontend**
- Flutter
- Dart

**Backend & Database**
- Supabase
- PostgreSQL
- Supabase Authentication

**AI**
- Gemini API

**Platforms**
- Android
- Web
- iOS
- Windows/macOS/Linux support through Flutter

## Architecture

Student App uses a Flutter frontend connected to Supabase for authentication and persistent data storage, with AI functionality integrated through an external AI API.

```text
Flutter Application
        │
        ├── Supabase Authentication
        │
        ├── Supabase Database
        │
        └── Gemini API
