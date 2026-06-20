# ==========================================
# Stage 1: Build VueJS Frontend
# ==========================================
FROM node:20-slim AS frontend-builder
WORKDIR /app
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# ==========================================
# Stage 2: Final Monolithic Image
# ==========================================
FROM php:8.4-fpm-bookworm

# Install Nginx, Supervisor, Python, and dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev

# Clean apt cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions for Laravel
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Setup Working Directory
WORKDIR /var/www

# Copy Laravel Backend
COPY backend/ /var/www
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Set Permissions
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

# Copy built VueJS frontend to Laravel public directory
COPY --from=frontend-builder /app/dist /var/www/public/frontend

# Setup Python Virtual Environment and Voice Server
WORKDIR /app-voice
COPY voice-server/requirements.txt ./
RUN python3 -m venv venv && \
    ./venv/bin/pip install --no-cache-dir -r requirements.txt
COPY voice-server/ ./

# Configure Nginx, Supervisor, and entrypoint
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

WORKDIR /var/www

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
