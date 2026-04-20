# ── Stage 1: Build React SPA ──────────────────────────────────────────────────
FROM node:20-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# dist/ is the output — CI/CD syncs this to the S3 frontend bucket

# ── Stage 2: Local dev server (nginx) ─────────────────────────────────────────
# In production the dist/ folder goes to S3, not a container.
# This stage is only used for local testing: docker build + docker run -p 8080:80
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
