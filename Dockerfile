FROM php:7.2-alpine
ARG url=https://github.com/InvoicePlane/InvoicePlane.git
ARG i8n_url=https://crowdin.com/backend/download/project/fusioninvoice/es-ES.zip
ARG i8n_path=application/language/
ARG port=8080
ENV deps="libpng-dev libjpeg-turbo-dev libmcrypt-dev libxml2-dev recode-dev freetype-dev"
ENV buildeps="git npm"
WORKDIR /var/www/html

COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN apk update && \
    apk add $buildeps $deps lighttpd && \
    git clone $url /var/www/html && \
    docker-php-ext-configure gd \
      --with-jpeg-dir=/usr/lib \
      --with-png-dir=/usr/lib && \
    docker-php-ext-install gd mysqli recode xmlrpc && \
    composer install -d ./

ADD --chown=lighttpd:lighttpd $i8n_url $i8n_path
COPY --chown=lighttpd:lighttpd . .
RUN sed 's/\(DB_HOSTNAME=\).*/\1db/ ; \
         s/\(DB_PORT=\).*/\13306/ ; \
         s/\(IP_URL=\).*/\1http:\/\/localhost:'${port}'/ ; \
         s/\(ENABLE_INVOICE_DELETION=\).*/\1true/ ; \
         s/\(DISABLE_READ_ONLY=\).*/\1true/' \
         ipconfig.php.example > ipconfig.php && \
    npm i && npm i -g grunt-cli
RUN grunt build && \
    apk del $buildeps && \
    unzip $i8n_path/*.zip -d $i8n_path && \
    rm $i8n_path/*.zip

ADD https://raw.githubusercontent.com/eficode/wait-for/master/wait-for .
# lighttpd configure
RUN ln -s /usr/local/bin/php-cgi /usr/bin/ && \
    mkdir /run/lighttpd && \
    chown -R lighttpd:lighttpd /run/lighttpd /var/www/html . && \
    chmod +x wait-for && \
    sed -i $'/"mod_fastcgi.conf"/s/^#// ; \
             /"mod_rewrite"/s/^#// ; \
             /server\.document-root/s/+.*// ; \
             s/usr\/bin/usr\/local\/bin/ ; \
             s/var\/www\/localhost/var\/www\/html/ ; \
             s/#\s*server\.port.*/server.port = '${port}'/ ; \
             /server\.pid-file/s/run/run\/lighttpd/ ; \
             $aurl.rewrite-if-not-file = ("(.*)" => "/index.php/$0")' \
      /etc/lighttpd/lighttpd.conf

USER lighttpd
ENTRYPOINT ["/usr/sbin/lighttpd"]
CMD ["-D", "-f", "/etc/lighttpd/lighttpd.conf"]
