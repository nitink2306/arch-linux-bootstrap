FROM nginx:alpine

COPY arch-install.sh /usr/share/nginx/html/arch-install.sh
COPY setup.sh /usr/share/nginx/html/setup.sh
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
