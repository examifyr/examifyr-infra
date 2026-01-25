# Examifyr – System Architecture

## Repositories
- examifyr-frontend (Next.js / React)
- examifyr-backend (FastAPI)
- examifyr-infra (source of truth)

## Local Development
Frontend: http://localhost:3000  
Backend:  http://127.0.0.1:8000

## Communication
- Frontend → Backend via REST
- Health check: GET /health

## Environment Variables
Frontend:
- NEXT_PUBLIC_API_URL

Backend:
- CORS enabled for localhost origins