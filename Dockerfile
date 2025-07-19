FROM php:8.3-fpm

# Install dependencies and clean up apt cache to reduce image size
RUN apt update \
    && apt install -y openssl zip curl libcurl3-dev libzip-dev libpng-dev libjpeg-dev libwebp-dev libonig-dev libxml2-dev git rsync default-mysql-client libssl-dev libmemcached-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-webp --with-jpeg \
    && docker-php-ext-install curl gd mbstring mysqli pdo pdo_mysql xml opcache

# Imagemagick as PHP extension
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions imagick/imagick@28f27044e435a2b203e32675e942eb8de620ee58

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"

# Install xdebug, apcu, and uploadprogress in a single layer
RUN pecl install xdebug apcu uploadprogress \
    && docker-php-ext-enable xdebug apcu uploadprogress

# Add vendor/bin to PATH, assuming your project root is /app
ENV PATH="${PATH}:/app/vendor/bin"

# Configure SSH for build-time access to private repositories
RUN mkdir /root/.ssh
RUN ln -s /run/secrets/ssh_key /root/.ssh/id_rsa
RUN ln -s /run/secrets/gitconfig /root/.gitconfig
